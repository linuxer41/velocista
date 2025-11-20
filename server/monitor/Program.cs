using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Net;
using System.Net.WebSockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace SerialWebSocketServer
{
    enum MessageType : byte
    {
        MSG_SYSTEM = 0,
        MSG_COMMAND_ACK = 1,
        MSG_UNIFIED_TELEMETRY = 2
    }

    enum CommandType : byte
    {
        CMD_SET_PID = 0,
        CMD_SET_SPEED = 1,
        CMD_SET_MODE = 2,
        CMD_CALIBRATE = 3,
        CMD_START = 4,
        CMD_STOP = 5,
        CMD_GET_STATUS = 6,
        CMD_TOGGLE_TELEMETRY = 7
    }

    [StructLayout(LayoutKind.Sequential)]
    struct SetPidCommand
    {
        public byte type;
        public float kp, ki, kd;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct SetSpeedCommand
    {
        public byte type;
        public short speed;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct SetModeCommand
    {
        public byte type;
        public byte mode;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct CalibrateCommand
    {
        public byte type;
    }

    class Program
    {
        static List<WebSocket> clients = new List<WebSocket>();
        static SerialPort? serialPort = null;
        static string currentPort = "";
        static bool running = true;


        static async Task Main(string[] args)
        {
            var cts = new CancellationTokenSource();
            Console.CancelKeyPress += (s, e) => { running = false; cts.Cancel(); e.Cancel = true; };

            var listener = new HttpListener();
            listener.Prefixes.Add("http://localhost:8080/");
            listener.Start();
            Console.WriteLine("WebSocket server listening on ws://localhost:8080");

            await RunServerAsync(listener, cts.Token);
            listener.Stop();
            Console.WriteLine("Server stopped.");
        }

        static async Task RunServerAsync(HttpListener listener, CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                var ctx = await listener.GetContextAsync();
                if (ctx.Request.IsWebSocketRequest)
                {
                    var wsCtx = await ctx.AcceptWebSocketAsync(null);
                    var ws = wsCtx.WebSocket;
                    lock (clients) clients.Add(ws);
                    _ = HandleWebSocket(ws);
                }
                else
                {
                    ctx.Response.StatusCode = 400;
                    ctx.Response.Close();
                }
            }
        }

        static async Task HandleWebSocket(WebSocket ws)
        {
            var buffer = new byte[1024];
            while (ws.State == WebSocketState.Open && running)
            {
                var result = await ws.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);
                if (result.MessageType == WebSocketMessageType.Text)
                {
                    var msg = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    await ProcessCommand(msg, ws);
                }
                else if (result.MessageType == WebSocketMessageType.Close) break;
            }
            lock (clients) clients.Remove(ws);
            ws.Dispose();
        }

        static async Task ProcessCommand(string json, WebSocket ws)
        {
            try
            {
                var cmd = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(json);
                if (cmd == null || !cmd.ContainsKey("type")) return;
                var type = cmd["type"].GetString();

                switch (type)
                {
                    case "get_devices":
                        await SendDevices(ws);
                        break;
                    case "select_device":
                        if (cmd.ContainsKey("port") && cmd["port"].GetString() != null)
                            await SelectDevice(cmd["port"].GetString()!, ws);
                        break;
                    case "set_pid":
                        if (serialPort?.IsOpen == true && cmd.ContainsKey("kp"))
                            SendSetPid(cmd["kp"].GetSingle(), cmd["ki"].GetSingle(), cmd["kd"].GetSingle());
                        break;
                    case "set_speed":
                        if (serialPort?.IsOpen == true && cmd.ContainsKey("speed"))
                            SendSetSpeed(cmd["speed"].GetInt16());
                        break;
                    case "set_mode":
                        if (serialPort?.IsOpen == true && cmd.ContainsKey("mode"))
                            SendSetMode(cmd["mode"].GetByte());
                        break;
                    case "calibrate": if (serialPort?.IsOpen == true) SendCalibrate(); break;
                    case "start":     if (serialPort?.IsOpen == true) SendStart();     break;
                    case "stop":      if (serialPort?.IsOpen == true) SendStop();      break;
                    case "get_status":if (serialPort?.IsOpen == true) SendGetStatus(); break;
                    case "toggle_telemetry": if (serialPort?.IsOpen == true) SendToggleTelemetry(); break;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error processing command: {ex.Message}");
            }
        }

        /* ====================  SERIAL  ==================== */
        static async Task SelectDevice(string port, WebSocket ws)
        {
            if (serialPort != null)
            {
                serialPort.DataReceived -= OnSerialData;
                if (serialPort.IsOpen)
                {
                    serialPort.Close();
                }
                currentPort = "";
            }
            try
            {
                serialPort = new SerialPort(port, 9600, Parity.None, 8, StopBits.One);
                serialPort.Open();
                currentPort = port;
                serialPort.DataReceived += OnSerialData;
                await SendSystemMessage(ws, "Dispositivo conectado");
            }
            catch (Exception ex)
            {
                await SendSystemMessage(ws, $"Error: {ex.Message}");
            }
        }

        static void OnSerialData(object sender, SerialDataReceivedEventArgs e)
        {
            try
            {
                while (serialPort != null && serialPort.IsOpen && serialPort.BytesToRead > 0)
                {
                    string line = serialPort.ReadLine();
                    if (!string.IsNullOrEmpty(line))
                    {
                        Console.WriteLine($"[RECV] Line: {line}");
                        ParseLine(line);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] Serial read error: {ex.Message}");
            }
        }

        static void ParseLine(string line)
        {
            // Parse CSV: type,value1,value2,...
            string[] parts = line.Split(',');
            if (parts.Length == 0) return;
            if (!byte.TryParse(parts[0], out byte type)) return;

            string json = DeserializeToJson(type, parts.Skip(1).ToArray());
            Console.WriteLine($"[PARSE] JSON: {json}");
            if (!string.IsNullOrEmpty(json)) BroadcastMessage(json);
        }


        static void SendCsv(string csv)
        {
            if (serialPort?.IsOpen != true) return;
            Console.WriteLine($"[SEND] {csv}");
            serialPort.WriteLine(csv);
        }

        /* ====================  ENVÍO DE COMANDOS  ==================== */
        static void SendSetPid(float kp, float ki, float kd)
        {
            string csv = $"{(byte)CommandType.CMD_SET_PID},{kp:F6},{ki:F6},{kd:F6}";
            Console.WriteLine($"[CMD] SET_PID - {csv}");
            SendCsv(csv);
        }

        static void SendSetSpeed(short speed)
        {
            string csv = $"{(byte)CommandType.CMD_SET_SPEED},{speed}";
            Console.WriteLine($"[CMD] SET_SPEED - {csv}");
            SendCsv(csv);
        }

        static void SendSetMode(byte mode)
        {
            string csv = $"{(byte)CommandType.CMD_SET_MODE},{mode}";
            string modeStr = mode switch
            {
                0 => "CALIBRATION",
                1 => "COMPETITION",
                2 => "TUNING",
                3 => "DEBUG",
                4 => "REMOTE_CONTROL",
                _ => $"UNKNOWN({mode})"
            };
            Console.WriteLine($"[CMD] SET_MODE - {csv} ({modeStr})");
            SendCsv(csv);
        }

        static void SendCalibrate()
        {
            string csv = $"{(byte)CommandType.CMD_CALIBRATE}";
            Console.WriteLine($"[CMD] CALIBRATE - {csv}");
            SendCsv(csv);
        }

        static void SendStart()
        {
            string csv = $"{(byte)CommandType.CMD_START}";
            Console.WriteLine($"[CMD] START - {csv}");
            SendCsv(csv);
        }

        static void SendStop()
        {
            string csv = $"{(byte)CommandType.CMD_STOP}";
            Console.WriteLine($"[CMD] STOP - {csv}");
            SendCsv(csv);
        }

        static void SendGetStatus()
        {
            string csv = $"{(byte)CommandType.CMD_GET_STATUS}";
            Console.WriteLine($"[CMD] GET_STATUS - {csv}");
            SendCsv(csv);
        }

        static void SendToggleTelemetry()
        {
            string csv = $"{(byte)CommandType.CMD_TOGGLE_TELEMETRY}";
            Console.WriteLine($"[CMD] TOGGLE_TELEMETRY - {csv}");
            SendCsv(csv);
        }

        /* ====================  UTILS  ==================== */

        static string DeserializeToJson(byte type, string[] parts)
        {
            var options = new JsonSerializerOptions { WriteIndented = true };
            string typeName = type switch
            {
                0 => "MSG_SYSTEM",
                1 => "MSG_COMMAND_ACK",
                2 => "MSG_UNIFIED_TELEMETRY",
                _ => $"UNKNOWN({type})"
            };
            Console.WriteLine($"[DECODE] Processing {typeName} (0x{type:X2}), parts: {string.Join(",", parts)}");

            switch (type)
            {
                case (byte)MessageType.MSG_SYSTEM:
                    return JsonSerializer.Serialize(new { type = "system", message = parts.Length > 0 ? parts[0] : "" }, options);
                case (byte)MessageType.MSG_COMMAND_ACK:
                    if (parts.Length < 1) return string.Empty;
                    return JsonSerializer.Serialize(new { type = "command_ack", command_type = byte.Parse(parts[0]) }, options);
                case (byte)MessageType.MSG_UNIFIED_TELEMETRY:
                    if (parts.Length < 31) return string.Empty;
                    short[] sensors = new short[6];
                    for (int i = 0; i < 6; i++) short.TryParse(parts[9 + i], out sensors[i]);
                    return JsonSerializer.Serialize(new
                    {
                        type = "unified_telemetry",
                        timestamp = uint.Parse(parts[0]),
                        operationMode = byte.Parse(parts[1]),
                        robotState = byte.Parse(parts[2]),
                        pwmLeft = short.Parse(parts[3]),
                        pwmRight = short.Parse(parts[4]),
                        rpmLeft = float.Parse(parts[5]),
                        rpmRight = float.Parse(parts[6]),
                        distanceTraveled = float.Parse(parts[7]),
                        ultrasonicDistance = float.Parse(parts[8]),
                        sensors = sensors,
                        sensorError = short.Parse(parts[15]),
                        sensorSum = short.Parse(parts[16]),
                        odometryX = float.Parse(parts[17]),
                        odometryY = float.Parse(parts[18]),
                        odometryTheta = float.Parse(parts[19]),
                        linePidKp = float.Parse(parts[20]),
                        linePidKi = float.Parse(parts[21]),
                        linePidKd = float.Parse(parts[22]),
                        linePidIntegral = float.Parse(parts[23]),
                        motorPidKp = float.Parse(parts[24]),
                        motorPidKi = float.Parse(parts[25]),
                        motorPidKd = float.Parse(parts[26]),
                        motorPidIntegral = float.Parse(parts[27]),
                        remoteConnected = byte.Parse(parts[28]),
                        remoteLeftSpeed = short.Parse(parts[29]),
                        remoteRightSpeed = short.Parse(parts[30])
                    }, options);
                default:
                    return string.Empty;
            }
        }

        static async Task SendDevices(WebSocket ws)
        {
            var ports = SerialPort.GetPortNames();
            var devices = new List<Dictionary<string, string>>();
            foreach (var p in ports) devices.Add(new Dictionary<string, string> { { "port", p }, { "desc", $"Serial Port {p}" } });
            var resp = new { type = "devices", devices };
            await SendToWebSocket(ws, JsonSerializer.Serialize(resp));
        }

        static async Task SendSystemMessage(WebSocket ws, string msg)
        {
            await SendToWebSocket(ws, JsonSerializer.Serialize(new { type = "system", message = msg }));
        }

        static void BroadcastMessage(string json)
        {
            lock (clients)
                foreach (var c in clients.ToArray())
                    if (c.State == WebSocketState.Open)
                        _ = SendToWebSocket(c, json);
        }

        static async Task SendToWebSocket(WebSocket ws, string msg)
        {
            var buf = Encoding.UTF8.GetBytes(msg);
            await ws.SendAsync(new ArraySegment<byte>(buf), WebSocketMessageType.Text, true, CancellationToken.None);
        }
    }
}