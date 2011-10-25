user = Wscript.Arguments(0)
domain = Wscript.Arguments(1)
Set obj = GetObject("winmgmts:\\.\root\cimv2")
Set account = obj.Get ("Win32_UserAccount.Name='" & user & "',Domain='" & domain & "'")
Wscript.Echo account.SID
