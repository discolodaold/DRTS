@echo off
PATH=C:\dmd\dmd\bin;C:\dmd\dm\bin;C:\dmd\dsss\bin;%PATH%
dsss build main.d -g -version=client -version=server
move main.exe ..\bin\
