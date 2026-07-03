import wave
import math
import struct

sample_rate = 44100.0
duration = 0.5
frequency = 1000.0

wavef = wave.open('assets/sounds/notification.wav','w')
wavef.setnchannels(1)
wavef.setsampwidth(2) 
wavef.setframerate(sample_rate)

for i in range(int(duration * sample_rate)):
    value = int(32767.0*math.cos(frequency*math.pi*float(i)/float(sample_rate)))
    data = struct.pack('<h', value)
    wavef.writeframesraw( data )
    
wavef.writeframes(b'')
wavef.close()
