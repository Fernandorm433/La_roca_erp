import wave
import math
import struct

sample_rate = 44100.0

def generate_tone(freq, duration, vol_start=1.0, vol_end=0.0):
    frames = []
    num_samples = int(duration * sample_rate)
    for i in range(num_samples):
        t = float(i) / sample_rate
        # Mezcla de onda senoidal y armónicos para que sea brillante y FUERTE
        sine = math.sin(2.0 * math.pi * freq * t)
        harmonic1 = math.sin(2.0 * math.pi * freq * 2.0 * t) * 0.4
        harmonic2 = math.sin(2.0 * math.pi * freq * 3.0 * t) * 0.2
        val = sine + harmonic1 + harmonic2
        
        # Envolvente (Decay) para que suene como una campana/notificación
        vol = vol_start + (vol_end - vol_start) * (float(i) / num_samples)
        
        # Amplificación extrema al límite de 16-bit sin saturar feo
        sample = int(min(max(val * vol * 28000.0, -32767), 32767))
        frames.append(struct.pack('<h', sample))
    return b''.join(frames)

# Tono 1: Medio rápido (Nota Mi)
tone1 = generate_tone(1318.51, 0.15, 1.0, 0.6)
# Tono 2: Agudo más largo (Nota Sol#) - Típico sonido de mensaje
tone2 = generate_tone(1661.22, 0.5, 1.0, 0.0)

wavef = wave.open('assets/sounds/notification.wav', 'w')
wavef.setnchannels(1)
wavef.setsampwidth(2)
wavef.setframerate(int(sample_rate))
wavef.writeframes(tone1 + tone2)
wavef.close()
print("Sonido fuerte generado.")
