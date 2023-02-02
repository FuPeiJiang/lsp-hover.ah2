#SingleInstance force
ListLines 0
KeyHistory 0
SendMode "Input" ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir A_ScriptDir ; Ensures a consistent starting directory.

; f3::Exitapp

JSON_parse(str) {

    c_:=1

    return JSON_value()

    JSON_value() {

        char_:=SubStr(str, c_, 1)
        Switch char_ {
            case "{":
                obj_:=Map()
                ;object
                c_++
                loop {
                    skip_s()
                    if (SubStr(str, c_, 1) == "}") {
                        c_++
                        return obj_
                    }

                    ; key_:=JSON_objKey()
                    ; a or "a"
                    if (SubStr(str, c_, 1) == "`"") {
                        RegExMatch(str, "(?:\\.|.)*?(?=`")", &OutputVar, c_ + 1)
                        key_:=StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(OutputVar.0, "\`"", "`"", true), "\f", "`f", true), "\r", "`r", true), "\n", "`n", true), "\b", "`b", true), "\t", "`t", true), "\\", "\", true)
                        c_+=OutputVar.Len
                    } else {
                        RegExMatch(str, ".*?(?=[\s:])", &OutputVar, c_)
                        key_:=OutputVar.0
                        c_+=OutputVar.Len
                    }

                    c_:=InStr(str, ":", true, c_) + 1
                    skip_s()

                    value_:=JSON_value()
                    obj_[key_]:=value_
                    obj_.DefineProp(key_, {Value: value_})

                    skip_s()
                    if (SubStr(str, c_, 1) == ",") {
                        c_++, skip_s()
                    }
                }
            case "[":
                arr_:=[]
                ;array
                c_++
                loop {
                    skip_s()
                    if (SubStr(str, c_, 1) == "]") {
                        c_++
                        return arr_
                    }

                    value_:=JSON_value()
                    arr_.Push(value_)

                    skip_s()
                    char_:=SubStr(str, c_, 1)
                    if (char_ == ",") {
                        c_++, skip_s()
                    }
                }
            case "`"":
                RegExMatch(str, "(?:\\.|.)*?(?=`")", &OutputVar, c_ + 1)
                unquoted:=StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(OutputVar.0, "\`"", "`"", true), "\f", "`f", true), "\r", "`r", true), "\n", "`n", true), "\b", "`b", true), "\t", "`t", true), "\\", "\", true)
                c_+=OutputVar.Len + 2
                return unquoted
            case "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                ; -100
                ; 100.0
                ; 1.0E+2
                ; 1E-2
                RegExMatch(str, "[0-9.eE\-+]*", &OutputVar, c_)
                c_+=OutputVar.Len
                return Number(OutputVar.0)
            case "t":
                ;"true"
                c_+=4
                return {a:1}
            case "f":
                ;"false"
                c_+=5
                return {a:0}
            case "n":
                ;"null"
                c_+=4
                return {a:-1}


        }
    }

    skip_s() {
        RegExMatch(str, "\s*", &OutputVar, c_)
        c_+=OutputVar.Len
    }
}

class ChildProcess {
    static counter:=0

    __New(CmdLine, onStdOutCallback, onStdErrCallback:=false, WorkingDir:="") { ;from zig : std.ChildProcess.exec() : https://github.com/ziglang/zig/blob/4624c818991f161fc6a7021119e4d071b6e40e6c/lib/std/child_process.zig#L373
        ChildProcess.counter++
        stderr_pipe_path:="\\.\pipe\ahk-childprocess-" DllCall("GetCurrentProcessId") "-" ChildProcess.counter
        ChildProcess.counter++
        stdout_pipe_path:="\\.\pipe\ahk-childprocess-" DllCall("GetCurrentProcessId") "-" ChildProcess.counter

        saAttr:=Buffer(24)
        NumPut("Uint",saAttr.Size,saAttr,0) ;nLength
        NumPut("Ptr",0,saAttr,8) ;lpSecurityDescriptor
        NumPut("Int",1,saAttr,16) ;bInheritHandle

        ;https://learn.microsoft.com/en-us/windows/win32/procthread/creating-a-child-process-with-redirected-input-and-output
        DllCall("CreatePipe"
            ,"Ptr*",&g_hChildStd_IN_Rd:=0
            ,"Ptr*",&g_hChildStd_IN_Wr:=0
            ,"Ptr",saAttr
            ,"Uint",0
        )

        bool:=DllCall("SetHandleInformation"
            ,"Ptr",g_hChildStd_IN_Wr
            ,"Uint",1 ;HANDLE_FLAG_INHERIT
            ,"Uint",0
        )

        g_hChildStd_ERR_Rd:=DllCall("CreateNamedPipe"
            ,"Str",stderr_pipe_path
            ,"Uint",0x40000001 ;0x00000001 | 0x40000000 ;PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED
            ,"Uint",0 ;0x00000000 ;PIPE_TYPE_BYTE
            ,"Uint",1
            ,"Uint",4096
            ,"Uint",4096
            ,"Uint",0
            ,"Ptr",saAttr
        )

        g_hChildStd_OUT_Rd:=DllCall("CreateNamedPipe"
            ,"Str",stdout_pipe_path
            ,"Uint",0x40000001 ;0x00000001 | 0x40000000 ;PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED
            ,"Uint",0 ;0x00000000 ;PIPE_TYPE_BYTE
            ,"Uint",1
            ,"Uint",4096
            ,"Uint",4096
            ,"Uint",0
            ,"Ptr",saAttr
        )

        g_hChildStd_ERR_Wr:=DllCall("CreateFile"
            ,"Str",stderr_pipe_path
            ,"Uint",0x40000000 ;GENERIC_WRITE
            ,"Uint",0
            ,"Ptr",saAttr
            ,"Uint",3 ;OPEN_EXISTING
            ,"Uint",0x80 ;FILE_ATTRIBUTE_NORMAL
            ,"Ptr",0
        )

        g_hChildStd_OUT_Wr:=DllCall("CreateFile"
            ,"Str",stdout_pipe_path
            ,"Uint",0x40000000 ;GENERIC_WRITE
            ,"Uint",0
            ,"Ptr",saAttr
            ,"Uint",3 ;OPEN_EXISTING
            ,"Uint",0x80 ;FILE_ATTRIBUTE_NORMAL
            ,"Ptr",0
        )

        bool:=DllCall("SetHandleInformation"
            ,"Ptr",g_hChildStd_ERR_Rd
            ,"Uint",1 ;HANDLE_FLAG_INHERIT
            ,"Uint",0
        )

        bool:=DllCall("SetHandleInformation"
            ,"Ptr",g_hChildStd_OUT_Rd
            ,"Uint",1 ;HANDLE_FLAG_INHERIT
            ,"Uint",0
        )

        P8 := (A_PtrSize==8)
        , SI:=Buffer(P8 ? 104 : 68, 0) ; STARTUPINFO structure
        , NumPut("UInt", P8 ? 104 : 68, SI) ; size of STARTUPINFO
        , NumPut("UInt", STARTF_USESTDHANDLES:=0x100, SI, P8 ? 60 : 44) ; dwFlags
        , NumPut("Ptr", g_hChildStd_IN_Rd, SI, P8 ? 80 : 56) ; hStdInput
        , NumPut("Ptr", g_hChildStd_OUT_Wr, SI, P8 ? 88 : 60) ; hStdOutput
        , NumPut("Ptr", g_hChildStd_ERR_Wr, SI, P8 ? 96 : 64) ; hStdError
        , PI:=Buffer(P8 ? 24 : 16) ; PROCESS_INFORMATION structure

        bool:=DllCall("CreateProcess"
            ,"Ptr",0
            ,"Str",CmdLine
            ,"Ptr",0 ;lpProcessAttributes: *SECURITY_ATTRIBUTES
            ,"Int",0 ;lpThreadAttributes: *SECURITY_ATTRIBUTES
            ,"Int",True
            ,"Uint",0x08000400 ;dwCreationFlags: CREATE_NO_WINDOW=0x08000000, CREATE_UNICODE_ENVIRONMENT=0x00000400
            ,"Int",0 ;lpEnvironment
            ,"Ptr",WorkingDir ? StrPtr(WorkingDir) : 0
            ,"Ptr",SI
            ,"Ptr",PI
        )

        ; bool:=DllCall("CloseHandle", "Ptr",NumGet(PI,0,"Ptr")) ;piProcInfo.hProcess
        ; bool:=DllCall("CloseHandle", "Ptr",NumGet(PI,P8 ? 8 : 4,"Ptr")) ;piProcInfo.hThread

        bool:=DllCall("CloseHandle", "Ptr",g_hChildStd_ERR_Wr) ;THIS IS MUST, THIS IS IN FACT SO NECESSARY THAT WaitForSingleObject WILL ALWAYS HANG/BE WAITING
        bool:=DllCall("CloseHandle", "Ptr",g_hChildStd_OUT_Wr) ;THIS IS MUST, THIS IS IN FACT SO NECESSARY THAT WaitForSingleObject WILL ALWAYS HANG/BE WAITING
        bool:=DllCall("CloseHandle", "Ptr",g_hChildStd_IN_Rd)

        this.g_hChildStd_IN_Wr := g_hChildStd_IN_Wr
        this.g_hChildStd_ERR_Rd:=g_hChildStd_ERR_Rd
        this.g_hChildStd_OUT_Rd:=g_hChildStd_OUT_Rd
        this.onStdErrCallback := onStdErrCallback
        this.onStdOutCallback := onStdOutCallback
        this.stderr_overlapped:=Buffer(32, 0)
        this.stdout_overlapped:=Buffer(32, 0)
        this.stderr_bump_amt:=512
        this.stdout_bump_amt:=512
        this.openPipes:=2

        while (true) {
            this.stderr_next_buf:=Buffer(this.stderr_bump_amt)
            bool:=DllCall("ReadFile"
                ,"Ptr",g_hChildStd_ERR_Rd
                ,"Ptr",this.stderr_next_buf
                ,"Uint",this.stderr_next_buf.Size
                ,"Uint*",&read_bytes:=0
                ,"Ptr",this.stderr_overlapped
            )
            if (bool == 1) {
                this.stderr_bump_amt+=read_bytes
                this.onStdErrCallback.Call(StrGet(this.stderr_next_buf,read_bytes,"UTF-8"))
            } else {
                switch (A_LastError) {
                    case 997: ;IO_PENDING
                        break
                    case 109: ;BROKEN_PIPE: The pipe has been ended.
                        break
                    default:
                        MsgBox "h89fh2398h4`nA_LastError: " A_LastError
                }
            }
        }
        while (true) {
            this.stdout_next_buf:=Buffer(this.stdout_bump_amt)
            bool:=DllCall("ReadFile"
                ,"Ptr",g_hChildStd_OUT_Rd
                ,"Ptr",this.stdout_next_buf
                ,"Uint",this.stdout_next_buf.Size
                ,"Uint*",&read_bytes:=0
                ,"Ptr",this.stdout_overlapped
            )
            if (bool == 1) {
                this.stdout_bump_amt+=read_bytes
                this.onStdOutCallback.Call(StrGet(this.stdout_next_buf,read_bytes,"UTF-8"))
            } else {
                switch (A_LastError) {
                    case 997: ;IO_PENDING
                        break
                    case 109: ;BROKEN_PIPE: The pipe has been ended.
                        break
                    default:
                        MsgBox "h89fh2398h4`nA_LastError: " A_LastError
                }
            }
        }

        this.timer := this.checkForStr.Bind(this)
        this.checkForStr()
        SetTimer this.timer, 10
    }

    checkForStr() {
        loop 1 {
            status:=DllCall("WaitForSingleObject"
                ,"Ptr",this.g_hChildStd_ERR_Rd
                ,"Uint",0
            )
            if (status == 258) {
                break
            } else if (status == 0) {
                bool:=DllCall("GetOverlappedResult"
                    ,"Ptr",this.g_hChildStd_ERR_Rd
                    ,"Ptr",this.stderr_overlapped
                    ,"Uint*", &Overlapped_read_bytes:=0
                    ,"Int",0
                )
                this.stderr_bump_amt+=Overlapped_read_bytes
                this.onStdErrCallback.Call(StrGet(this.stderr_next_buf,Overlapped_read_bytes,"UTF-8"))

                while (true) {
                    this.stderr_next_buf:=Buffer(this.stderr_bump_amt)
                    bool:=DllCall("ReadFile"
                        ,"Ptr",this.g_hChildStd_ERR_Rd
                        ,"Ptr",this.stderr_next_buf
                        ,"Uint",this.stderr_next_buf.Size
                        ,"Uint*",&read_bytes:=0
                        ,"Ptr",this.stderr_overlapped
                    )
                    if (bool == 1) {
                        this.stderr_bump_amt+=read_bytes
                        this.onStdErrCallback.Call(StrGet(this.stderr_next_buf,read_bytes,"UTF-8"))
                    } else {
                        switch (A_LastError) {
                            case 997: ;IO_PENDING
                                break
                            case 109: ;BROKEN_PIPE: The pipe has been ended.
                                --this.openPipes
                                if (this.openPipes == 0) {
                                    SetTimer this.timer, 0
                                    return
                                } else {
                                    break
                                }
                            default:
                                MsgBox "h89fh2398h4`nA_LastError: " A_LastError
                        }
                    }
                }
            } else {
                MsgBox "no way: " status
            }
        }

        loop 1 {
            status:=DllCall("WaitForSingleObject"
                ,"Ptr",this.g_hChildStd_OUT_Rd
                ,"Uint",0
            )
            if (status == 258) {
                break
            } else if (status == 0) {
                bool:=DllCall("GetOverlappedResult"
                    ,"Ptr",this.g_hChildStd_OUT_Rd
                    ,"Ptr",this.stdout_overlapped
                    ,"Uint*", &Overlapped_read_bytes:=0
                    ,"Int",0
                )
                this.stdout_bump_amt+=Overlapped_read_bytes
                this.onStdOutCallback.Call(StrGet(this.stdout_next_buf,Overlapped_read_bytes,"UTF-8"))

                while (true) {
                    this.stdout_next_buf:=Buffer(this.stdout_bump_amt)
                    bool:=DllCall("ReadFile"
                        ,"Ptr",this.g_hChildStd_OUT_Rd
                        ,"Ptr",this.stdout_next_buf
                        ,"Uint",this.stdout_next_buf.Size
                        ,"Uint*",&read_bytes:=0
                        ,"Ptr",this.stdout_overlapped
                    )
                    if (bool == 1) {
                        this.stdout_bump_amt+=read_bytes
                        this.onStdOutCallback.Call(StrGet(this.stdout_next_buf,read_bytes,"UTF-8"))
                    } else {
                        switch (A_LastError) {
                            case 997: ;IO_PENDING
                                break
                            case 109: ;BROKEN_PIPE: The pipe has been ended.
                                --this.openPipes
                                if (this.openPipes == 0) {
                                    SetTimer this.timer, 0
                                    return
                                } else {
                                    break
                                }
                            default:
                                MsgBox "h89fh2398h4`nA_LastError: " A_LastError
                        }
                    }
                }
            } else {
                MsgBox "no way: " status
            }
        }


    }

    noMoreStdIn() {
        bool:=DllCall("CloseHandle", "Ptr",this.g_hChildStd_IN_Wr)
    }

    writeBufToStdIn(wowBuf) {
        DllCall("WriteFile"
        ,"Ptr",this.g_hChildStd_IN_Wr
        ,"Ptr",wowBuf
        ,"Uint",wowBuf.Size - 1
        ,"Ptr*",&byteswritten:=0
        ,"Ptr",0
    )
    }

    writeStrToStdIn(str) {
        ; Calculate required size and allocate a buffer.
        wowBuf := Buffer(StrPut(str, "UTF-8"))
        ; Copy or convert the string.
        StrPut(str, wowBuf, "UTF-8")

        this.writeBufToStdIn(wowBuf)
    }
}

finalStr:=""
contentLength:=0
onStdOutCallback(str) {
    global finalStr, contentLength, pos_CRLFCRLF, resultFunction

    finalStr.=str
    loop {
        if (contentLength) {
            if (StrLen(finalStr) > contentLength + pos_CRLFCRLF + 2) {
                jsonObj:=JSON_parse(SubStr(finalStr, pos_CRLFCRLF + 4, contentLength))
                finalStr:=SubStr(finalStr,pos_CRLFCRLF + 4 + contentLength)
                contentLength:=0

                if (jsonObj.Has("result")) {
                    if (type(jsonObj["result"]) == "Map") {
                        resultFunction(jsonObj["result"])
                    } else {
                        ; it's `false`
                        if (SubStr(lastVar,1,7)!=="sizeof(") {
                            getWord("sizeof(" lastVar ")")
                        }
                    }
                    ; FileAppend "`n`nstars beyond`n`n", "*"
                }
                continue
            } else {
                break
            }
        } else {
            pos_CRLFCRLF:=InStr(finalStr, "`r`n`r`n", true)
            if (pos_CRLFCRLF) {
                contentLength:=Integer(SubStr(finalStr, 17, pos_CRLFCRLF - 17))
                continue
            } else {
                break
            }
        }
    }
    ; FileAppend str, "*"


}
onStdErrCallback(str) {
    ; global finalStr

    ; finalStr.=str
    ; Tooltip finalStr

    ; FileAppend str, "*"
}
pythonProcess := ChildProcess(A_LineFile "\..\clangd.exe", onStdOutCallback, onStdErrCallback)

sendRequest(okayStr) {
    global pythonProcess
    wowBuf := Buffer(StrPut(okayStr, "UTF-8"))
    StrPut(okayStr, wowBuf, "UTF-8")
    pythonProcess.writeStrToStdIn("Content-Length: " wowBuf.Size - 1 "`r`n`r`n")
    pythonProcess.writeBufToStdIn(wowBuf)
}

resultFunctionSomething(resultObj) {
    value:=resultObj["contents"]["value"]
    ; MsgBox A_Clipboard:=value
    c_:=1
    c_:=InStr(value, "`n", true, c_ + 1)
    c_:=InStr(value, "`n", true, c_ + 1)
    c_:=InStr(value, "`n", true, c_ + 1)
    c_:=InStr(value, "`n", true, c_ + 1)
    c_:=InStr(value, "``", true, c_ + 1)

    ; pos_backtick:=InStr(value, "``", true, c_ + 1)
    ; varValue:=Integer(SubStr(value, c_ + 1, pos_backtick - c_ - 1))

    RegExMatch(value, "\d*", &OutputVar, c_ + 1)
    varValue:=Integer(OutputVar.0)
    ToolTip A_Clipboard:=varValue
    ; ToolTip A_Clipboard:=Format("0x{:08X}", varValue)
}
resultFunctionInit(resultObj) {
    global resultFunction
    resultFunction:=resultFunctionSomething
}

resultFunction:=resultFunctionInit
sendRequest("{`"jsonrpc`":`"2.0`",`"id`":0,`"method`":`"initialize`",`"params`":{`"processId`":" DllCall("GetCurrentProcessId") ",`"clientInfo`":{`"name`":`"Visual Studio Code`",`"version`":`"1.74.2`"},`"locale`":`"en-us`",`"rootPath`":null,`"rootUri`":null,`"capabilities`":{`"workspace`":{`"applyEdit`":true,`"workspaceEdit`":{`"documentChanges`":true,`"resourceOperations`":[`"create`",`"rename`",`"delete`"],`"failureHandling`":`"textOnlyTransactional`",`"normalizesLineEndings`":true,`"changeAnnotationSupport`":{`"groupsOnLabel`":true}},`"configuration`":true,`"didChangeWatchedFiles`":{`"dynamicRegistration`":true,`"relativePatternSupport`":true},`"symbol`":{`"dynamicRegistration`":true,`"symbolKind`":{`"valueSet`":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]},`"tagSupport`":{`"valueSet`":[1]},`"resolveSupport`":{`"properties`":[`"location.range`"]}},`"codeLens`":{`"refreshSupport`":true},`"executeCommand`":{`"dynamicRegistration`":true},`"didChangeConfiguration`":{`"dynamicRegistration`":true},`"workspaceFolders`":true,`"semanticTokens`":{`"refreshSupport`":true},`"fileOperations`":{`"dynamicRegistration`":true,`"didCreate`":true,`"didRename`":true,`"didDelete`":true,`"willCreate`":true,`"willRename`":true,`"willDelete`":true},`"inlineValue`":{`"refreshSupport`":true},`"inlayHint`":{`"refreshSupport`":true},`"diagnostics`":{`"refreshSupport`":true}},`"textDocument`":{`"publishDiagnostics`":{`"relatedInformation`":true,`"versionSupport`":false,`"tagSupport`":{`"valueSet`":[1,2]},`"codeDescriptionSupport`":true,`"dataSupport`":true},`"synchronization`":{`"dynamicRegistration`":true,`"willSave`":true,`"willSaveWaitUntil`":true,`"didSave`":true},`"completion`":{`"dynamicRegistration`":true,`"contextSupport`":true,`"completionItem`":{`"snippetSupport`":true,`"commitCharactersSupport`":true,`"documentationFormat`":[`"markdown`",`"plaintext`"],`"deprecatedSupport`":true,`"preselectSupport`":true,`"tagSupport`":{`"valueSet`":[1]},`"insertReplaceSupport`":true,`"resolveSupport`":{`"properties`":[`"documentation`",`"detail`",`"additionalTextEdits`"]},`"insertTextModeSupport`":{`"valueSet`":[1,2]},`"labelDetailsSupport`":true},`"insertTextMode`":2,`"completionItemKind`":{`"valueSet`":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25]},`"completionList`":{`"itemDefaults`":[`"commitCharacters`",`"editRange`",`"insertTextFormat`",`"insertTextMode`"]},`"editsNearCursor`":true},`"hover`":{`"dynamicRegistration`":true,`"contentFormat`":[`"markdown`",`"plaintext`"]},`"signatureHelp`":{`"dynamicRegistration`":true,`"signatureInformation`":{`"documentationFormat`":[`"markdown`",`"plaintext`"],`"parameterInformation`":{`"labelOffsetSupport`":true},`"activeParameterSupport`":true},`"contextSupport`":true},`"definition`":{`"dynamicRegistration`":true,`"linkSupport`":true},`"references`":{`"dynamicRegistration`":true},`"documentHighlight`":{`"dynamicRegistration`":true},`"documentSymbol`":{`"dynamicRegistration`":true,`"symbolKind`":{`"valueSet`":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]},`"hierarchicalDocumentSymbolSupport`":true,`"tagSupport`":{`"valueSet`":[1]},`"labelSupport`":true},`"codeAction`":{`"dynamicRegistration`":true,`"isPreferredSupport`":true,`"disabledSupport`":true,`"dataSupport`":true,`"resolveSupport`":{`"properties`":[`"edit`"]},`"codeActionLiteralSupport`":{`"codeActionKind`":{`"valueSet`":[`"`",`"quickfix`",`"refactor`",`"refactor.extract`",`"refactor.inline`",`"refactor.rewrite`",`"source`",`"source.organizeImports`"]}},`"honorsChangeAnnotations`":false},`"codeLens`":{`"dynamicRegistration`":true},`"formatting`":{`"dynamicRegistration`":true},`"rangeFormatting`":{`"dynamicRegistration`":true},`"onTypeFormatting`":{`"dynamicRegistration`":true},`"rename`":{`"dynamicRegistration`":true,`"prepareSupport`":true,`"prepareSupportDefaultBehavior`":1,`"honorsChangeAnnotations`":true},`"documentLink`":{`"dynamicRegistration`":true,`"tooltipSupport`":true},`"typeDefinition`":{`"dynamicRegistration`":true,`"linkSupport`":true},`"implementation`":{`"dynamicRegistration`":true,`"linkSupport`":true},`"colorProvider`":{`"dynamicRegistration`":true},`"foldingRange`":{`"dynamicRegistration`":true,`"rangeLimit`":5000,`"lineFoldingOnly`":true,`"foldingRangeKind`":{`"valueSet`":[`"comment`",`"imports`",`"region`"]},`"foldingRange`":{`"collapsedText`":false}},`"declaration`":{`"dynamicRegistration`":true,`"linkSupport`":true},`"selectionRange`":{`"dynamicRegistration`":true},`"callHierarchy`":{`"dynamicRegistration`":true},`"semanticTokens`":{`"dynamicRegistration`":true,`"tokenTypes`":[`"namespace`",`"type`",`"class`",`"enum`",`"interface`",`"struct`",`"typeParameter`",`"parameter`",`"variable`",`"property`",`"enumMember`",`"event`",`"function`",`"method`",`"macro`",`"keyword`",`"modifier`",`"comment`",`"string`",`"number`",`"regexp`",`"operator`",`"decorator`"],`"tokenModifiers`":[`"declaration`",`"definition`",`"readonly`",`"static`",`"deprecated`",`"abstract`",`"async`",`"modification`",`"documentation`",`"defaultLibrary`"],`"formats`":[`"relative`"],`"requests`":{`"range`":true,`"full`":{`"delta`":true}},`"multilineTokenSupport`":false,`"overlappingTokenSupport`":false,`"serverCancelSupport`":true,`"augmentsSyntaxTokens`":true},`"linkedEditingRange`":{`"dynamicRegistration`":true},`"typeHierarchy`":{`"dynamicRegistration`":true},`"inlineValue`":{`"dynamicRegistration`":true},`"inlayHint`":{`"dynamicRegistration`":true,`"resolveSupport`":{`"properties`":[`"tooltip`",`"textEdits`",`"label.tooltip`",`"label.location`",`"label.command`"]}},`"diagnostic`":{`"dynamicRegistration`":true,`"relatedDocumentSupport`":false}},`"window`":{`"showMessage`":{`"messageActionItem`":{`"additionalPropertiesSupport`":true}},`"showDocument`":{`"support`":true},`"workDoneProgress`":true},`"general`":{`"staleRequestSupport`":{`"cancel`":true,`"retryOnContentModified`":[`"textDocument/semanticTokens/full`",`"textDocument/semanticTokens/range`",`"textDocument/semanticTokens/full/delta`"]},`"regularExpressions`":{`"engine`":`"ECMAScript`",`"version`":`"ES2020`"},`"markdown`":{`"parser`":`"marked`",`"version`":`"1.1.0`"},`"positionEncodings`":[`"utf-16`"]},`"notebookDocument`":{`"synchronization`":{`"dynamicRegistration`":true,`"executionSummarySupport`":true}}},`"initializationOptions`":{`"clangdFileStatus`":true,`"fallbackFlags`":[]},`"trace`":`"off`",`"workspaceFolders`":null}}")
sendRequest("{`"jsonrpc`":`"2.0`",`"method`":`"textDocument/didOpen`",`"params`":{`"textDocument`":{`"uri`":`"file:///c%3A/get%20enum%20value.c`",`"languageId`":`"c`",`"version`":1,`"text`":`"#include <stdio.h>\n#include \`"C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.19041.0\\um\\Windows.h\`"\n#include \`"C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.19041.0\\um\\dwmapi.h\`"\n#include \`"C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.19041.0\\um\\TlHelp32.h\`"\n\nint main() {\n    printf(\`"%d\`", (size_t)DWMWA_BORDER_COLOR);\n}`"}}}")

lastVar:="DWMWA_BORDER_COLOR"
lengthLastVar:=StrLen(lastVar)
versionNum:=1

getWord(word_) {
    global lastVar, nextVar, versionNum, lengthLastVar

    nextVar:=word_
    ++versionNum
    sendRequest("{`"jsonrpc`":`"2.0`",`"method`":`"textDocument/didChange`",`"params`":{`"textDocument`":{`"uri`":`"file:///c%3A/get%20enum%20value.c`",`"version`":" versionNum "},`"contentChanges`":[{`"range`":{`"start`":{`"line`":6,`"character`":25},`"end`":{`"line`":6,`"character`":" 25 + lengthLastVar "}},`"rangeLength`":" lengthLastVar ",`"text`":`"" nextVar "`"}]}}")
    lastVar:=nextVar
    sendRequest("{`"jsonrpc`":`"2.0`",`"id`":1,`"method`":`"textDocument/hover`",`"params`":{`"textDocument`":{`"uri`":`"file:///c%3A/get%20enum%20value.c`"},`"position`":{`"line`":6,`"character`":17}}}")
    lengthLastVar:=StrLen(lastVar)
}

$f1::{
    Send "^c"
    Sleep 100
    getWord(A_Clipboard)
    ; try it on these:
    ; DWMWA_BORDER_COLOR
    ; DWMWA_DISALLOW_PEEK
    ; STARTUPINFOA
    ; DWORD
}
