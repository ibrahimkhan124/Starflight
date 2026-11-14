#!/usr/bin/env python3
"""Deterministic original sci-fi sound design; Python stdlib only.

PCM stereo, 44.1 kHz. Loops crossfade their noise beds at the wrap; all
transients have attack/release envelopes and conservative peak headroom.
Run this script again to reproduce the complete bundled sound library.
"""
from pathlib import Path
import json
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'AlpineFlight/Resources'
EXTRA = RESOURCES / 'Audio'
EXTRA.mkdir(exist_ok=True)
RATE = 44100
TAU = math.tau
LOOPS = {'engine', 'jet', 'ion', 'warp', 'pod', 'wind', 'skid', 'weather_rain', 'weather_snow', 'weather_dust', 'weather_mist'}
DURATIONS = {**dict.fromkeys(LOOPS, 4.0), 'impact': 2.0, 'checkpoint': .85,
             'laser': .30, 'laser_heavy': .48, 'laser_ion': .32, 'shield': .55,
             'weather_thunder': 4.5, 'hyperspace': 5.0, 'arrival': 1.15, 'boost': 1.0, 'droid': .65}
LEGACY = {'engine', 'jet', 'impact', 'checkpoint', 'laser'}


def noise_bed(count, seed, cutoff, loop):
    rng = random.Random(seed)
    fade = int(RATE*.09) if loop else 0
    alpha = 1-math.exp(-TAU*cutoff/RATE)
    state = 0.0
    values = []
    for _ in range(count+fade):
        state += alpha*(rng.uniform(-1, 1)-state)
        values.append(state)
    if loop:
        for i in range(fade):
            w = .5-.5*math.cos(math.pi*i/(fade-1))
            values[i] = values[count+i]*(1-w)+values[i]*w
    return values[:count]


def tone(frequency, t, phase=0):
    return math.sin(TAU*frequency*t+phase)


def synth(name):
    duration = DURATIONS[name]
    count = round(duration*RATE)
    loop = name in LOOPS
    seed = sum((i+1)*ord(c) for i,c in enumerate(name))
    low = noise_bed(count, seed, 240 if loop else 900, loop)
    high = noise_bed(count, seed+73, 3100 if loop else 6600, loop)
    left, right = [], []
    for i in range(count):
        t = i/RATE
        n, hiss = low[i], high[i]
        if name == 'engine':
            # Large freighter: low turbine rumble, staggered drive harmonics.
            s = .28*tone(48,t)+.12*tone(96,t)+.06*tone(192,t)+n*.55+hiss*.07
            s *= .91+.06*tone(1.5,t)+.03*tone(7,t)
        elif name == 'jet':
            # Agile fighter: turbine body and a restrained electrical whine.
            s = .18*tone(84,t)+.09*tone(168,t)+.035*tone(504,t)+n*.45+hiss*.16
            s *= .92+.04*tone(2,t)+.04*tone(13,t)
        elif name == 'ion':
            s = .17*tone(63,t)+.12*math.sin(TAU*189*t+.9*tone(31.5,t))+n*.22+hiss*.08
            s *= .80+.12*tone(6,t)+.08*tone(12,t)
        elif name == 'warp':
            s = .20*tone(54,t)+.10*tone(81,t)+.07*tone(162,t)+.025*tone(432,t)+n*.22
            s *= .92+.08*tone(.5,t)
        elif name == 'pod':
            s = .24*tone(72,t)+.12*tone(144,t)+.06*tone(216,t)+n*.62+hiss*.15
            s *= .78+.13*tone(18,t)+.09*tone(36,t)
        elif name == 'wind':
            s = n*.55+hiss*.48
            s *= .76+.16*tone(.75,t)+.08*tone(1.25,t)
        elif name == 'skid':
            s = n*.28+hiss*.42+.10*math.sin(TAU*340*t+1.8*tone(23,t))
            s *= .70+.30*abs(tone(12,t))
        elif name == 'weather_rain':
            s = hiss*.65+n*.18
            s *= .85+.08*tone(.5,t)+.07*tone(1.25,t)
            s += .06*abs(tone(173,t)*tone(277,t))*hiss
        elif name == 'weather_snow':
            s = n*.85+hiss*.22
            s *= .62+.22*tone(.5,t)+.12*tone(1.25,t)
        elif name == 'weather_dust':
            s = n*.7+hiss*.45+.045*tone(46,t)
            s *= .72+.18*tone(.75,t)+.1*tone(1.5,t)
        elif name == 'weather_mist':
            s = n*.8+hiss*.10
            s *= .8+.12*tone(.25,t)+.08*tone(.5,t)
        elif name == 'weather_thunder':
            s = (n*.9+hiss*.17)*math.exp(-t*.9)*(1-math.exp(-t*7))
            s += .10*tone(38,t)*math.exp(-t*1.2)
        elif name == 'impact':
            s = (n*.85+hiss*.42)*math.exp(-t*4.2)
            s += .48*math.sin(TAU*(72*t-14*t*t))*math.exp(-t*3.8)
            s += .10*tone(387,t)*math.exp(-t*11)+.07*tone(913,t)*math.exp(-t*14)
        elif name.startswith('laser'):
            base, fall, body = {'laser':(1120,490,.18),'laser_heavy':(660,390,.38),'laser_ion':(1480,720,.16)}[name]
            phase = TAU*((base-fall)*t+fall*duration*(1-math.exp(-t/duration)))
            s = (.35*math.sin(phase+2.8*math.exp(-t*11)*tone(base*.43,t))+hiss*.14)*math.exp(-t*11)
            s += body*tone(86 if name == 'laser_heavy' else 150,t)*math.exp(-t*16)
        elif name == 'shield':
            s = (.35*math.sin(TAU*(310*t+90*t*t))+.2*tone(97,t)+hiss*.22)*math.exp(-t*8)
        elif name == 'checkpoint':
            s = 0
            for start,f in [(0,523.25),(.12,659.25),(.24,783.99)]:
                local = t-start
                if local >= 0:
                    s += (.19*tone(f,local)+.06*tone(f*2,local))*min(1,local/.012)*math.exp(-local*8)
        elif name == 'droid':
            note = min(4,int(t/.13)); local = t-note*.13
            frequency = [740,1120,920,1390,1060][note]
            s = .30*math.sin(TAU*(frequency*local+210*local*local)+.55*tone(44,local))
            s *= math.sin(math.pi*min(1,local/.13))**2
        elif name == 'hyperspace':
            launch = math.exp(-((t-.55)/.32)**2)
            tunnel = math.sin(math.pi*min(1,t/5))**.8
            s = (n*.55+hiss*.3)*tunnel + .24*tone(44,t)*launch
            s += .08*math.sin(TAU*(120*t+45*t*t))*tunnel
            s *= .6+launch*.5
        elif name == 'arrival':
            s = (n*.6+hiss*.23)*math.exp(-t*5)+.25*tone(58,t)*math.exp(-t*6)
            s += .07*tone(554.37,t)*math.exp(-t*4)
        elif name == 'boost':
            s = (.25*math.sin(TAU*(100*t+75*t*t))+n*.65+hiss*.26)*math.exp(-t*2.7)
        envelope = 1 if loop else min(1,t/.006)*min(1,(duration-t)/.065)
        # Small stereo width, with the low body kept in the centre for phone speakers.
        width = .025 if loop else .012
        left.append(math.tanh((s*.9+width*hiss)*envelope))
        right.append(math.tanh((s*.9-width*hiss)*envelope))
    if loop:
        # A 3 ms eased join also closes the stereo noise at the exact PCM seam.
        join = round(RATE*.003)
        for channel in (left,right):
            for i in range(join):
                w = .5-.5*math.cos(math.pi*i/(join-1))
                channel[-join+i] = channel[-join+i]*(1-w)+channel[0]*w
    peak = max(max(map(abs,left)),max(map(abs,right)))
    target = .58 if loop else .76
    gain = target/max(peak,1e-9)
    frames = bytearray()
    sum_sq = 0
    for l,r in zip(left,right):
        l *= gain; r *= gain
        sum_sq += (l*l+r*r)/2
        frames.extend(struct.pack('<hh',round(l*32767),round(r*32767)))
    path = (RESOURCES if name in LEGACY else EXTRA)/(name+'.wav')
    with wave.open(str(path),'wb') as file:
        file.setnchannels(2); file.setsampwidth(2); file.setframerate(RATE); file.writeframes(frames)
    seam = max(abs(left[0]-left[-1]),abs(right[0]-right[-1]))*gain
    assert peak > .001
    assert not loop or seam < .025, (name,'loop discontinuity',seam)
    return dict(seconds=duration,peak=target,rms=round(math.sqrt(sum_sq/count),5),loop=loop,seam=round(seam,6),bytes=len(frames)+44)


if __name__ == '__main__':
    import sys
    names = [name for name in DURATIONS if name.startswith('weather_')] if '--weather-only' in sys.argv else sorted(DURATIONS)
    report = {name:synth(name) for name in names}
    folder = ROOT/'Art/Audio'; folder.mkdir(exist_ok=True)
    (folder/('weather-audit.json' if '--weather-only' in sys.argv else 'sound-audit.json')).write_text(json.dumps(report,indent=2)+'\n')
    print('Generated',len(report),'original stereo effects; peaks, loop seams and WAV data checked.')
