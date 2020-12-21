@ECHO OFF
cmd /c 7z x "%3%\%1.pk3" levelshots/%2.dds -so | magick convert dds:- jpg:- | openssl base64