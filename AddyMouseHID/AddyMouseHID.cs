using System;
using System.Runtime.InteropServices;

namespace AddyMouseHID
{
    public class MouseDeltaEventArgs : EventArgs
    {
        public int X { get; }
        public int Y { get; }
        public int Buttons { get; }
        public int Wheel { get; }

        public MouseDeltaEventArgs(int x, int y, int buttons, int wheel)
        {
            X = x;
            Y = y;
            Buttons = buttons;
            Wheel = wheel;
        }
    }

    public class MouseReader : IDisposable
    {
        private const int WM_INPUT = 0x00FF;
        private const int RIDEV_INPUTSINK = 0x00000100;
        private const int RID_INPUT = 0x10000003;
        
        public event EventHandler<MouseDeltaEventArgs> OnMouseDelta;
        private NativeWindow nativeWindow;
        
        [StructLayout(LayoutKind.Sequential)]
        private struct RAWINPUTDEVICE
        {
            public ushort usUsagePage;
            public ushort usUsage;
            public uint dwFlags;
            public IntPtr hwndTarget;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct RAWINPUTHEADER
        {
            public uint dwType;
            public uint dwSize;
            public IntPtr hDevice;
            public IntPtr wParam;
        }

        [DllImport("user32.dll")]
        private static extern bool RegisterRawInputDevices(RAWINPUTDEVICE[] pRawInputDevices, uint uiNumDevices, uint cbSize);

        [DllImport("user32.dll")]
        private static extern uint GetRawInputData(IntPtr hRawInput, uint uiCommand, IntPtr pData, ref uint pcbSize, uint cbSizeHeader);

        [DllImport("user32.dll")]
        private static extern IntPtr CreateWindowEx(int dwExStyle, string lpClassName, string lpWindowName, int dwStyle, int x, int y, int nWidth, int nHeight, IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);

        [DllImport("user32.dll")]
        private static extern bool DestroyWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern IntPtr DefWindowProc(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern ushort RegisterClass(ref WNDCLASS lpWndClass);

        [StructLayout(LayoutKind.Sequential)]
        private struct WNDCLASS
        {
            public uint style;
            public IntPtr lpfnWndProc;
            public int cbClsExtra;
            public int cbWndExtra;
            public IntPtr hInstance;
            public IntPtr hIcon;
            public IntPtr hCursor;
            public IntPtr hbrBackground;
            public string lpszMenuName;
            public string lpszClassName;
        }

        private class NativeWindow : IDisposable
        {
            private const string WINDOW_CLASS = "MouseReaderWindow";
            private IntPtr hWnd;
            private delegate IntPtr WndProcDelegate(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
            private WndProcDelegate wndProcDelegate;

            [DllImport("user32.dll", SetLastError = true)]
            private static extern bool UnregisterClass(string lpClassName, IntPtr hInstance);

            public event EventHandler<MouseDeltaEventArgs> MouseMoved;

            public NativeWindow()
            {
                wndProcDelegate = WndProc;
                var wc = new WNDCLASS
                {
                    lpfnWndProc = Marshal.GetFunctionPointerForDelegate(wndProcDelegate),
                    lpszClassName = WINDOW_CLASS,
                    hInstance = GetModuleHandle(null)
                };
                RegisterClass(ref wc);
                hWnd = CreateWindowEx(0, WINDOW_CLASS, "", 0, 0, 0, 0, 0, IntPtr.Zero, IntPtr.Zero, wc.hInstance, IntPtr.Zero);
            }

            public IntPtr Handle => hWnd;

            private IntPtr WndProc(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam)
            {
                if (msg == WM_INPUT) ProcessRawInput(lParam);
                return DefWindowProc(hWnd, msg, wParam, lParam);
            }

            private unsafe void ProcessRawInput(IntPtr hRawInput)
            {
                uint dwSize = 0;
                GetRawInputData(hRawInput, RID_INPUT, IntPtr.Zero, ref dwSize, (uint)Marshal.SizeOf<RAWINPUTHEADER>());
                if (dwSize == 0) return;

                IntPtr buffer = Marshal.AllocHGlobal((int)dwSize);
                try
                {
                    if (GetRawInputData(hRawInput, RID_INPUT, buffer, ref dwSize, (uint)Marshal.SizeOf<RAWINPUTHEADER>()) != dwSize)
                        return;

                    uint dwType = (uint)Marshal.ReadInt32(buffer, 0);
                    if (dwType == 0) // Mouse
                    {
                        int headerSize = 24;
                        short buttonFlags = Marshal.ReadInt16(buffer, headerSize + 4);
                        short scrollDelta = Marshal.ReadInt16(buffer, headerSize + 6);
                        int lLastX = Marshal.ReadInt32(buffer, headerSize + 12);
                        int lLastY = Marshal.ReadInt32(buffer, headerSize + 16);

                        if ((buttonFlags & 0x0400) != 0 || lLastX != 0 || lLastY != 0 || buttonFlags != 0)
                        {
                            MouseMoved?.Invoke(this, new MouseDeltaEventArgs(lLastX, lLastY, (int)buttonFlags, (int)scrollDelta));
                        }
                    }
                }
                finally { Marshal.FreeHGlobal(buffer); }
            }

            public void Dispose()
            {
                if (hWnd != IntPtr.Zero)
                {
                    DestroyWindow(hWnd);
                    UnregisterClass(WINDOW_CLASS, GetModuleHandle(null));
                    hWnd = IntPtr.Zero;
                }
            }
        }

        public void Start()
        {
            if (nativeWindow != null) Stop();
            nativeWindow = new NativeWindow();
            nativeWindow.MouseMoved += (s, e) => OnMouseDelta?.Invoke(this, e);
            
            var rid = new RAWINPUTDEVICE[1];
            rid[0].usUsagePage = 0x01;
            rid[0].usUsage = 0x02;
            rid[0].dwFlags = RIDEV_INPUTSINK;
            rid[0].hwndTarget = nativeWindow.Handle;

            if (!RegisterRawInputDevices(rid, 1, (uint)Marshal.SizeOf<RAWINPUTDEVICE>()))
                throw new Exception("Failed to register raw input device.");
        }

        public void Stop()
        {
            nativeWindow?.Dispose();
            nativeWindow = null;
        }

        public void Dispose()
        {
            Stop();
        }
    }
}