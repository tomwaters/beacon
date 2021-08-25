# beacon
***
beacon is a norns script for sample mangling by entering commands using a computer keyboard.

#### Requirements
- [x] norns
- [x] a USB computer keyboard
- [x] some samples


## Quick Start
*(AKA just tell me how to make some noise)*

Make sure your keyboard is connected to your norns and start the script

Enter the following pressing enter at the end of each line

```
load audio/tehn/whirl1.aif 1
voice 1 1
play 1
```
These comands will **load** a sample into the first of two buffers, set the first **voice** of six to use that first buffer and then **play** the first voice.

You can use the up and down arrows to move through the history of commands you have entered. Press the up arrow once and press enter to hear the sample again.

The **help** command will list all available commands.
A command followed by *help* will give help about that command e.g.
```
help load
```
Commands that require a *voice* parameter will generally give the current settings by entering the command with just the voice number e.g.
```
every 1
```
Commands that don't require a voice parameter will generally give the current setting by just entering the command with no parameters e.g.
```
bpm
```

## Commands
Parameters in \< \> are required, those in ( ) are optional.

[bpm \<bpm\>](#bpm)

[load \<file\> (b#)](#load)

[voice \<v#\> \<b#\>](#voice)

[level \<v#\> \<l\>](#level)

[range \<v#\> \<s\> \<e\>](#range)

[rate \<v#\> \<r1\> (r2) (p)](#rate)

[rate_slew \<v#\> \<s\>](#rate_slew)

[play \<v#\>](#play)

[stop \<v#\>](#stop)

[loop \<v#\>](#loop)

[every \<v#\> \<x\> \<b/s\> (n%)](#every)

[euc \<v#\> \<p\> \<s\> (o)](#euc)

[*filter \<v#\> \<off/hp/lp/bp\> \<f\> (q)*](#filter)

Use the UP and DOWN arrow keys to scroll through command history.

Use LEFT, RIGHT, HOME and END to move around the current command line.

Use ESC to clear the current command line.

### bpm
*bpm \<bpm\>*

Sets the norns clock tempo to the specified value.
Enter the command without a tempo to see the current tempo.
```
bpm 120
```

### load
*load \<file\> (b#)*

Loads the specified file into a buffer (1 or 2).
If no buffer number is specified the file is loaded as stereo - left channel to buffer 1 and right channel to buffer 2.
```
load audio/tehn/whirl1.aif 1
```

### voice
*voice \<v#\> \<b#\>*

Sets the specified voice (1 to 6) to use the specified buffer (1 or 2).
Enter with just a voice to view the current buffer for that voice.
```
voice 5 2
```

### level
*level \<v#\> \<l\>*

Sets the amplitude for the specified voice (1 to 6).
Enter with just a voice to view the current level for that voice.
```
level 1 0.5
```

### range
*range \<v#\> \<s\> \<e\>*

Sets the start and end point (in seconds) of the buffer to use for the specified voice.
Enter with just a voice to view the current range for that voice.
```
range 1 1.25 2
```

### rate
*rate \<v#\> \<r\> (r2) (p)*

Set the rate to play the specified voice (1.0 is default speed, 2.0 is twice speed etc).

Enter a min and max rate to play at a random rate between the two. 

Enter a comma separated list of rates (e.g. 1,1.2,2) followed by a pattern (up/dn/rnd) to play a sequence.
```
rate 1 2
rate 1 0.8 1.5
rate 1 0.5,1,1.5 rnd
```
Enter with just a voice to view the current rate for that voice.

### rate_slew
*rate_slew \<v#\> \<s\>*

Set the slew time (in seconds) when changing the rate of the specified voice.

```
rate_slew 1 2
```

### play
*play \<v#\>*

Plays the specified voice as a one off.
```
play 1
```

### stop
*stop \<v#\>*

Stops playing the specified voice
```
stop 1
```

### loop
*loop \<v#\>*

Loop play the specified voice
```
loop 1
```

### every
*every \<v#\> \<x\> \<b/s\> (n%)*

Play the specified voice every *x* beats (b) or seconds (s).
The optional n parameter specified the chance of the sound playing.
```
every 1 1 b
every 1 10 s
every 1 4 b 75%
```
Enter with just a voice to view the current every for that voice.

### euc
*euc \<v#\> \<p\> \<s\> (o)*

Generates a euclidean rhythm of *p* pulses in *s* steps with an optional *o* offset for use in conjunction with *every* for the specified voice.

When *every* would normally play the voice, the current step of the euc sequence in checked and if set, the voice plays.

Enter with just a voice to view the current euc settings for that voice.
```
euc 1 5 8
euc 2 12 16 2
```

### filter
*filter \<v#\> \<off/hp/lp/bp\> \<f\> (q)*

Sets the filter to the specified voice to off, high pass (hp), low pass (lp) or band pass (bp) at the specified frequency with an optional Q factor.

```
filter 1 lp 15000
filter 3 bp 2000 1
filter 6 off 
```
