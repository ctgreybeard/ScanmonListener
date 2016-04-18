# ScanmonListener
An iOS app to listen to my scanner

I have a scanner at home, A Uniden BCD996XT, that is attached to a Raspberry Pi 2 
running a darkice->icecast streamer. 
This app connects to that system and plays the audio stream.
Title changes are detected and displayed.

Change Log --

V0.2.0 - UI improvments. Failure recovery more robust, failed connections are retried after 5 seconds if AutoRetry is selected in the options.
