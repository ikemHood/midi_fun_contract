use core::traits::TryInto;
use orion::operators::tensor::{Tensor, U32Tensor,};
use orion::numbers::FP32x32;
use core::option::OptionTrait;
use koji::midi::types::{
    Midi, Message, Modes, ArpPattern, VelocityCurve, NoteOn, NoteOff, SetTempo, TimeSignature,
    ControlChange, PitchWheel, AfterTouch, PolyTouch, Direction, PitchClass, ProgramChange,
    SystemExclusive,
};
use alexandria_data_structures::stack::{StackTrait, Felt252Stack, NullableStack};
use alexandria_data_structures::array_ext::{ArrayTraitExt, SpanTraitExt};

use koji::midi::instruments::{
    GeneralMidiInstrument, instrument_name, instrument_to_program_change,
    program_change_to_instrument, next_instrument_in_group
};
use koji::midi::time::round_to_nearest_nth;
use koji::midi::modes::{mode_steps};
use koji::midi::pitch::{PitchClassTrait, keynum_to_pc, pc_to_keynum};
use koji::midi::velocitycurve::{VelocityCurveTrait};

trait MidiTrait {
    /// =========== NOTE MANIPULATION ===========
    /// Instantiate a Midi.
    fn new() -> Midi;
    /// create music to be consumed by web app - maybe add flags to reverse notes
    fn music(
        reverse: i32,
        semitones: i32,
        grid_size: usize,
        factor: i32,
        new_tempo: u32,
        chanel: u32,
        steps: i32,
        tonic: PitchClass,
        modes: Modes
    ) -> Midi;
    /// Append a message in a Midi object.
    fn append_message(self: @Midi, msg: Message) -> Midi;
    /// Transpose notes by a given number of semitones.
    fn transpose_notes(self: @Midi, semitones: i32) -> Midi;
    ///  Reverse the order of notes.
    fn reverse_notes(self: @Midi) -> Midi;
    /// Align notes to a given rhythmic grid.
    fn quantize_notes(self: @Midi, grid_size: usize) -> Midi;
    /// Extract notes within a specified pitch range.
    fn extract_notes(self: @Midi, note_range: usize) -> Midi;
    /// Change the duration of notes by a given factor
    fn change_note_duration(self: @Midi, factor: i32) -> Midi;
    /// =========== GLOBAL MANIPULATION ===========
    /// Alter the tempo of the Midi data.
    fn change_tempo(self: @Midi, new_tempo: u32) -> Midi;
    /// Change instrument patches based on a provided mapping
    fn remap_instruments(self: @Midi, chanel: u32) -> Midi;
    /// =========== ANALYSIS ===========
    /// Extract the tempo (in BPM) from the Midi data.
    fn get_bpm(self: @Midi) -> u32;
    /// Return statistics about notes (e.g., most frequent note, average note duration).
    /// =========== ADVANCED MANIPULATION ===========
    /// Add harmonies to existing melodies based on specified intervals.
    fn generate_harmony(self: @Midi, steps: i32, tonic: PitchClass, modes: Modes) -> Midi;
    /// Convert chords into arpeggios based on a given pattern.
    fn arpeggiate_chords(self: @Midi, pattern: ArpPattern) -> Midi;
    /// Add or modify dynamics (velocity) of notes based on a specified curve or pattern.
    fn edit_dynamics(self: @Midi, curve: VelocityCurve) -> Midi;
    /// Add notes one or more octaves higher or lower
    fn octave_double(self: @Midi, octave_count: i32) -> Midi;
}

impl MidiImpl of MidiTrait {
    fn new() -> Midi {
        Midi { events: array![].span() }
    }

    // Current basic midi structure for playback

    fn music(
        reverse: i32,
        semitones: i32,
        grid_size: usize,
        factor: i32,
        new_tempo: u32,
        chanel: u32,
        steps: i32,
        tonic: PitchClass,
        modes: Modes
    ) -> Midi {
        let mut eventlist = ArrayTrait::<Message>::new();

        // Set Instrument

        let outpc = ProgramChange {
            channel: 0, program: 7, time: FP32x32 { mag: 6000, sign: false }
        };

        let pcmessage = Message::PROGRAM_CHANGE((outpc));

        // Set Instrument

        let newtempo = SetTempo { tempo: 0, time: Option::Some(FP32x32 { mag: 0, sign: false }) };

        // Create Notes

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 0, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 21, velocity: 100, time: FP32x32 { mag: 1000, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 21, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let tempomessage = Message::SET_TEMPO((newtempo));

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
       
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
            
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        eventlist.append(tempomessage);
        
        eventlist.append(pcmessage);

        eventlist.append(notemessageon1);
            
        eventlist.append(notemessageon2);
        
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);

        eventlist.append(notemessageoff2);

        eventlist.append(notemessageoff3);

        let mut basemidi = Midi { events: eventlist.span() };

        let mut finalMidi = basemidi
            .transpose_notes(semitones)
            .quantize_notes(grid_size)
            .change_note_duration(factor)
            .change_tempo(new_tempo)
            .remap_instruments(chanel)
            .generate_harmony(steps, tonic, modes);

        if reverse == 0 { //could be a bool
        } else {
            finalMidi = finalMidi.reverse_notes();
        }

        finalMidi
    }

    fn append_message(self: @Midi, msg: Message) -> Midi {
        let mut ev = *self.events;
        let mut output = array![];

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => { output.append(*currentevent); },
                Option::None(_) => { break; },
            };
        };

        output.append(msg);
        Midi { events: output.span() }
    }

    fn transpose_notes(self: @Midi, semitones: i32) -> Midi {
        let mut ev = self.clone().events;
        let mut eventlist = ArrayTrait::<Message>::new();

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            let outnote = if semitones < 0 {
                                *NoteOn.note - semitones.try_into().unwrap()
                            } else {
                                *NoteOn.note + semitones.try_into().unwrap()
                            };
                            let newnote = NoteOn {
                                channel: *NoteOn.channel,
                                note: outnote,
                                velocity: *NoteOn.velocity,
                                time: *NoteOn.time
                            };
                            let notemessage = Message::NOTE_ON((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            let outnote = if semitones < 0 {
                                *NoteOff.note - semitones.try_into().unwrap()
                            } else {
                                *NoteOff.note + semitones.try_into().unwrap()
                            };

                            let newnote = NoteOff {
                                channel: *NoteOff.channel,
                                note: outnote,
                                velocity: *NoteOff.velocity,
                                time: *NoteOff.time
                            };
                            let notemessage = Message::NOTE_OFF((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::SET_TEMPO(_SetTempo) => { eventlist.append(*currentevent); },
                        Message::TIME_SIGNATURE(_TimeSignature) => {
                            eventlist.append(*currentevent);
                        },
                        Message::CONTROL_CHANGE(_ControlChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::PITCH_WHEEL(_PitchWheel) => { eventlist.append(*currentevent); },
                        Message::AFTER_TOUCH(_AfterTouch) => { eventlist.append(*currentevent); },
                        Message::POLY_TOUCH(_PolyTouch) => { eventlist.append(*currentevent); },
                        Message::PROGRAM_CHANGE(_ProgramChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {
                            eventlist.append(*currentevent);
                        },
                    }
                },
                Option::None(_) => { break; }
            };
        };

        Midi { events: eventlist.span() }
    }

    fn reverse_notes(self: @Midi) -> Midi {
        let mut ev = self.clone().events;
        let mut rev = self.clone().events.reverse().span();
        let lastmsgtime = rev.pop_front();
        let firstmsgtime = ev.pop_front();
        let mut maxtime = FP32x32 { mag: 0, sign: false };
        let mut mintime = FP32x32 { mag: 0, sign: false };
        let mut eventlist = ArrayTrait::<Message>::new();

        //assign maxtime to the last message's time value in the Midi
        match lastmsgtime {
            Option::Some(currentev) => {
                match currentev {
                    Message::NOTE_ON(NoteOn) => { maxtime = *NoteOn.time; },
                    Message::NOTE_OFF(NoteOff) => { maxtime = *NoteOff.time; },
                    Message::SET_TEMPO(SetTempo) => {
                        match *SetTempo.time {
                            Option::Some(time) => { maxtime = time; },
                            Option::None => {},
                        }
                    },
                    Message::TIME_SIGNATURE(TimeSignature) => {
                        match *TimeSignature.time {
                            Option::Some(time) => { maxtime = time; },
                            Option::None => {},
                        }
                    },
                    Message::CONTROL_CHANGE(ControlChange) => { maxtime = *ControlChange.time; },
                    Message::PITCH_WHEEL(PitchWheel) => { maxtime = *PitchWheel.time; },
                    Message::AFTER_TOUCH(AfterTouch) => { maxtime = *AfterTouch.time; },
                    Message::POLY_TOUCH(PolyTouch) => { maxtime = *PolyTouch.time; },
                    Message::PROGRAM_CHANGE(ProgramChange) => { maxtime = *ProgramChange.time; },
                    Message::SYSTEM_EXCLUSIVE(SystemExclusive) => {
                        maxtime = *SystemExclusive.time;
                    },
                }
            },
            Option::None(_) => {}
        };

        //assign mintime to the first message's time value
        match firstmsgtime {
            Option::Some(currentev) => {
                match currentev {
                    Message::NOTE_ON(NoteOn) => { mintime = *NoteOn.time; },
                    Message::NOTE_OFF(NoteOff) => { mintime = *NoteOff.time; },
                    Message::SET_TEMPO(SetTempo) => {
                        match *SetTempo.time {
                            Option::Some(time) => { mintime = time; },
                            Option::None => {},
                        }
                    },
                    Message::TIME_SIGNATURE(TimeSignature) => {
                        match *TimeSignature.time {
                            Option::Some(time) => { mintime = time; },
                            Option::None => {},
                        }
                    },
                    Message::CONTROL_CHANGE(ControlChange) => { mintime = *ControlChange.time; },
                    Message::PITCH_WHEEL(PitchWheel) => { mintime = *PitchWheel.time; },
                    Message::AFTER_TOUCH(AfterTouch) => { mintime = *AfterTouch.time; },
                    Message::POLY_TOUCH(PolyTouch) => { mintime = *PolyTouch.time; },
                    Message::PROGRAM_CHANGE(ProgramChange) => { mintime = *ProgramChange.time; },
                    Message::SYSTEM_EXCLUSIVE(SystemExclusive) => {
                        mintime = *SystemExclusive.time;
                    },
                }
            },
            Option::None(_) => {}
        };

        loop {
            match rev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            let newnote = NoteOff {
                                channel: *NoteOn.channel,
                                note: *NoteOn.note,
                                velocity: *NoteOn.velocity,
                                time: ((maxtime - *NoteOn.time) + mintime)
                            };
                            let notemessage = Message::NOTE_OFF((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            let newnote = NoteOn {
                                channel: *NoteOff.channel,
                                note: *NoteOff.note,
                                velocity: *NoteOff.velocity,
                                time: (maxtime - *NoteOff.time) + mintime
                            };
                            let notemessage = Message::NOTE_ON((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::SET_TEMPO(SetTempo) => {
                            let scaledtempo = SetTempo {
                                tempo: *SetTempo.tempo,
                                time: match *SetTempo.time {
                                    Option::Some(time) => Option::Some((maxtime - time) + mintime),
                                    Option::None => Option::None,
                                }
                            };
                            let tempomessage = Message::SET_TEMPO((scaledtempo));
                            eventlist.append(tempomessage);
                        },
                        Message::TIME_SIGNATURE(TimeSignature) => {
                            let newtimesig = TimeSignature {
                                numerator: *TimeSignature.numerator,
                                denominator: *TimeSignature.denominator,
                                clocks_per_click: *TimeSignature.clocks_per_click,
                                time: match *TimeSignature.time {
                                    Option::Some(time) => Option::Some((maxtime - time) + mintime),
                                    Option::None => Option::None,
                                }
                            };
                            let tsmessage = Message::TIME_SIGNATURE((newtimesig));
                            eventlist.append(tsmessage);
                        },
                        Message::CONTROL_CHANGE(ControlChange) => {
                            let newcontrolchange = ControlChange {
                                channel: *ControlChange.channel,
                                control: *ControlChange.control,
                                value: *ControlChange.value,
                                time: (maxtime - *ControlChange.time) + mintime
                            };
                            let ccmessage = Message::CONTROL_CHANGE((newcontrolchange));
                            eventlist.append(ccmessage);
                        },
                        Message::PITCH_WHEEL(PitchWheel) => {
                            let newpitchwheel = PitchWheel {
                                channel: *PitchWheel.channel,
                                pitch: *PitchWheel.pitch,
                                time: (maxtime - *PitchWheel.time) + mintime
                            };
                            let pwmessage = Message::PITCH_WHEEL((newpitchwheel));
                            eventlist.append(pwmessage);
                        },
                        Message::AFTER_TOUCH(AfterTouch) => {
                            let newaftertouch = AfterTouch {
                                channel: *AfterTouch.channel,
                                value: *AfterTouch.value,
                                time: (maxtime - *AfterTouch.time) + mintime
                            };
                            let atmessage = Message::AFTER_TOUCH((newaftertouch));
                            eventlist.append(atmessage);
                        },
                        Message::POLY_TOUCH(PolyTouch) => {
                            let newpolytouch = PolyTouch {
                                channel: *PolyTouch.channel,
                                note: *PolyTouch.note,
                                value: *PolyTouch.value,
                                time: (maxtime - *PolyTouch.time) + mintime
                            };
                            let ptmessage = Message::POLY_TOUCH((newpolytouch));
                            eventlist.append(ptmessage);
                        },
                        Message::PROGRAM_CHANGE(ProgramChange) => {
                            let newprogchg = ProgramChange {
                                channel: *ProgramChange.channel,
                                program: *ProgramChange.program,
                                time: (maxtime - *ProgramChange.time) + mintime
                            };
                            let pchgmessage = Message::PROGRAM_CHANGE((newprogchg));
                            eventlist.append(pchgmessage);
                        },
                        Message::SYSTEM_EXCLUSIVE(SystemExclusive) => {
                            let newsysex = SystemExclusive {
                                manufacturer_id: *SystemExclusive.manufacturer_id,
                                device_id: *SystemExclusive.device_id,
                                data: *SystemExclusive.data,
                                checksum: *SystemExclusive.checksum,
                                time: (maxtime - *SystemExclusive.time) + mintime
                            };
                            let sysexgmessage = Message::SYSTEM_EXCLUSIVE((newsysex));
                            eventlist.append(sysexgmessage);
                        },
                    }
                },
                Option::None(_) => { break; }
            };
        };

        Midi { events: eventlist.span() }
    }

    fn quantize_notes(self: @Midi, grid_size: usize) -> Midi {
        let mut ev = self.clone().events;
        let mut eventlist = ArrayTrait::<Message>::new();

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            let newnote = NoteOn {
                                channel: *NoteOn.channel,
                                note: *NoteOn.note,
                                velocity: *NoteOn.velocity,
                                time: round_to_nearest_nth(*NoteOn.time, grid_size)
                            };
                            let notemessage = Message::NOTE_ON((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            let newnote = NoteOff {
                                channel: *NoteOff.channel,
                                note: *NoteOff.note,
                                velocity: *NoteOff.velocity,
                                time: round_to_nearest_nth(*NoteOff.time, grid_size)
                            };
                            let notemessage = Message::NOTE_OFF((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::SET_TEMPO(_SetTempo) => { eventlist.append(*currentevent) },
                        Message::TIME_SIGNATURE(_TimeSignature) => {
                            eventlist.append(*currentevent)
                        },
                        Message::CONTROL_CHANGE(_ControlChange) => {
                            eventlist.append(*currentevent)
                        },
                        Message::PITCH_WHEEL(_PitchWheel) => { eventlist.append(*currentevent) },
                        Message::AFTER_TOUCH(_AfterTouch) => { eventlist.append(*currentevent) },
                        Message::POLY_TOUCH(_PolyTouch) => { eventlist.append(*currentevent) },
                        Message::PROGRAM_CHANGE(_ProgramChange) => {
                            eventlist.append(*currentevent)
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {
                            eventlist.append(*currentevent);
                        },
                    }
                },
                Option::None(_) => { break; }
            };
        };

        // Create a new Midi object with the modified event list
        Midi { events: eventlist.span() }
    }

    fn extract_notes(self: @Midi, note_range: usize) -> Midi {
        let mut ev = self.clone().events;

        let middlec = 60;
        let mut lowerbound = 0;
        let mut upperbound = 127;

        if note_range < middlec {
            lowerbound = middlec - note_range;
        }
        if note_range + middlec < 127 {
            upperbound = middlec + note_range;
        }

        let mut eventlist = ArrayTrait::<Message>::new();

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            let currentnoteon = *NoteOn.note;
                            if currentnoteon > lowerbound.try_into().unwrap()
                                && currentnoteon < upperbound.try_into().unwrap() {
                                eventlist.append(*currentevent);
                            }
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            let currentnoteoff = *NoteOff.note;
                            if currentnoteoff > lowerbound.try_into().unwrap()
                                && currentnoteoff < upperbound.try_into().unwrap() {
                                eventlist.append(*currentevent);
                            }
                        },
                        Message::SET_TEMPO(_SetTempo) => {},
                        Message::TIME_SIGNATURE(_TimeSignature) => {},
                        Message::CONTROL_CHANGE(_ControlChange) => {},
                        Message::PITCH_WHEEL(_PitchWheel) => {},
                        Message::AFTER_TOUCH(_AfterTouch) => {},
                        Message::POLY_TOUCH(_PolyTouch) => {},
                        Message::PROGRAM_CHANGE(_ProgramChange) => {},
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };

        // Create a new Midi object with the modified event list
        Midi { events: eventlist.span() }
    }


    fn change_note_duration(self: @Midi, factor: i32) -> Midi {
        let newfactor = FP32x32 { mag: factor.try_into().unwrap(), sign: (factor < 0) };
        let mut ev = self.clone().events;
        let mut eventlist = ArrayTrait::<Message>::new();

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            let newnote = NoteOn {
                                channel: *NoteOn.channel,
                                note: *NoteOn.note,
                                velocity: *NoteOn.velocity,
                                time: *NoteOn.time * newfactor
                            };
                            let notemessage = Message::NOTE_ON((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            let newnote = NoteOff {
                                channel: *NoteOff.channel,
                                note: *NoteOff.note,
                                velocity: *NoteOff.velocity,
                                time: *NoteOff.time * newfactor
                            };
                            let notemessage = Message::NOTE_OFF((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::SET_TEMPO(SetTempo) => {
                            let scaledtempo = SetTempo {
                                tempo: *SetTempo.tempo,
                                time: match *SetTempo.time {
                                    Option::Some(time) => Option::Some(time * newfactor),
                                    Option::None => Option::None,
                                }
                            };
                            let tempomessage = Message::SET_TEMPO((scaledtempo));
                            eventlist.append(tempomessage);
                        },
                        Message::TIME_SIGNATURE(TimeSignature) => {
                            let newtimesig = TimeSignature {
                                numerator: *TimeSignature.numerator,
                                denominator: *TimeSignature.denominator,
                                clocks_per_click: *TimeSignature.clocks_per_click,
                                time: match *TimeSignature.time {
                                    Option::Some(time) => Option::Some(time * newfactor),
                                    Option::None => Option::None,
                                }
                            };
                            let tsmessage = Message::TIME_SIGNATURE((newtimesig));
                            eventlist.append(tsmessage);
                        },
                        Message::CONTROL_CHANGE(ControlChange) => {
                            let newcontrolchange = ControlChange {
                                channel: *ControlChange.channel,
                                control: *ControlChange.control,
                                value: *ControlChange.value,
                                time: *ControlChange.time * newfactor
                            };
                            let ccmessage = Message::CONTROL_CHANGE((newcontrolchange));
                            eventlist.append(ccmessage);
                        },
                        Message::PITCH_WHEEL(PitchWheel) => {
                            let newpitchwheel = PitchWheel {
                                channel: *PitchWheel.channel,
                                pitch: *PitchWheel.pitch,
                                time: *PitchWheel.time * newfactor
                            };
                            let pwmessage = Message::PITCH_WHEEL((newpitchwheel));
                            eventlist.append(pwmessage);
                        },
                        Message::AFTER_TOUCH(AfterTouch) => {
                            let newaftertouch = AfterTouch {
                                channel: *AfterTouch.channel,
                                value: *AfterTouch.value,
                                time: *AfterTouch.time * newfactor
                            };
                            let atmessage = Message::AFTER_TOUCH((newaftertouch));
                            eventlist.append(atmessage);
                        },
                        Message::POLY_TOUCH(PolyTouch) => {
                            let newpolytouch = PolyTouch {
                                channel: *PolyTouch.channel,
                                note: *PolyTouch.note,
                                value: *PolyTouch.value,
                                time: *PolyTouch.time * newfactor
                            };
                            let ptmessage = Message::POLY_TOUCH((newpolytouch));
                            eventlist.append(ptmessage);
                        },
                        Message::PROGRAM_CHANGE(ProgramChange) => {
                            let newprogchg = ProgramChange {
                                channel: *ProgramChange.channel,
                                program: *ProgramChange.program,
                                time: *ProgramChange.time * newfactor
                            };
                            let pchgmessage = Message::PROGRAM_CHANGE((newprogchg));
                            eventlist.append(pchgmessage);
                        },
                        Message::SYSTEM_EXCLUSIVE(SystemExclusive) => {
                            let newsysex = SystemExclusive {
                                manufacturer_id: *SystemExclusive.manufacturer_id,
                                device_id: *SystemExclusive.device_id,
                                data: *SystemExclusive.data,
                                checksum: *SystemExclusive.checksum,
                                time: *SystemExclusive.time * newfactor
                            };
                            let sysexgmessage = Message::SYSTEM_EXCLUSIVE((newsysex));
                            eventlist.append(sysexgmessage);
                        },
                    }
                },
                Option::None(_) => { break; }
            };
        };

        // Create a new Midi object with the modified event list
        Midi { events: eventlist.span() }
    }

    fn change_tempo(self: @Midi, new_tempo: u32) -> Midi {
        // Create a clone of the MIDI events
        let mut ev = self.clone().events;

        // Create a new array to store the modified events
        let mut eventlist = ArrayTrait::<Message>::new();

        loop {
            // Use pop_front to get the next event
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    // Process the current event
                    match currentevent {
                        Message::NOTE_ON(_NoteOn) => { eventlist.append(*currentevent); },
                        Message::NOTE_OFF(_NoteOff) => { eventlist.append(*currentevent); },
                        Message::SET_TEMPO(SetTempo) => {
                            // Create a new SetTempo message with the updated tempo
                            let tempo = SetTempo { tempo: new_tempo, time: *SetTempo.time };
                            let tempomessage = Message::SET_TEMPO((tempo));
                            eventlist.append(tempomessage);
                        },
                        Message::TIME_SIGNATURE(_TimeSignature) => {
                            eventlist.append(*currentevent);
                        },
                        Message::CONTROL_CHANGE(_ControlChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::PITCH_WHEEL(_PitchWheel) => { eventlist.append(*currentevent); },
                        Message::AFTER_TOUCH(_AfterTouch) => { eventlist.append(*currentevent); },
                        Message::POLY_TOUCH(_PolyTouch) => { eventlist.append(*currentevent); },
                        Message::PROGRAM_CHANGE(_ProgramChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {
                            eventlist.append(*currentevent);
                        },
                    }
                },
                Option::None(_) => {
                    // If there are no more events, break out of the loop
                    break;
                }
            };
        };

        // Create a new Midi object with the modified event list
        Midi { events: eventlist.span() }
    }

    fn remap_instruments(self: @Midi, chanel: u32) -> Midi {
        // Create a clone of the MIDI events
        let mut ev = self.clone().events;

        // Create a new array to store the modified events
        let mut eventlist = ArrayTrait::<Message>::new();

        loop {
            // Use pop_front to get the next event
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    // Process the current event
                    match currentevent {
                        Message::NOTE_ON(_NoteOn) => { eventlist.append(*currentevent); },
                        Message::NOTE_OFF(_NoteOff) => { eventlist.append(*currentevent); },
                        Message::SET_TEMPO(_SetTempo) => {
                            // Create a new SetTempo message with the updated tempo
                            eventlist.append(*currentevent);
                        },
                        Message::TIME_SIGNATURE(_TimeSignature) => {
                            eventlist.append(*currentevent);
                        },
                        Message::CONTROL_CHANGE(_ControlChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::PITCH_WHEEL(_PitchWheel) => { eventlist.append(*currentevent); },
                        Message::AFTER_TOUCH(_AfterTouch) => { eventlist.append(*currentevent); },
                        Message::POLY_TOUCH(_PolyTouch) => { eventlist.append(*currentevent); },
                        Message::PROGRAM_CHANGE(ProgramChange) => {
                            let newprogchg = ProgramChange {
                                channel: *ProgramChange.channel,
                                program: next_instrument_in_group(*ProgramChange.program),
                                time: *ProgramChange.time
                            };
                            let pchgmessage = Message::PROGRAM_CHANGE((newprogchg));
                            eventlist.append(pchgmessage);
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {
                            eventlist.append(*currentevent);
                        },
                    }
                },
                Option::None(_) => {
                    // If there are no more events, break out of the loop
                    break;
                }
            };
        };

        // Create a new Midi object with the modified event list
        Midi { events: eventlist.span() }
    }

    fn get_bpm(self: @Midi) -> u32 {
        // Iterate through the MIDI events, find and return the SetTempo message
        let mut ev = self.clone().events;
        let mut outtempo: u32 = 0;

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(_NoteOn) => {},
                        Message::NOTE_OFF(_NoteOff) => {},
                        Message::SET_TEMPO(SetTempo) => { outtempo = *SetTempo.tempo; },
                        Message::TIME_SIGNATURE(_TimeSignature) => {},
                        Message::CONTROL_CHANGE(_ControlChange) => {},
                        Message::PITCH_WHEEL(_PitchWheel) => {},
                        Message::AFTER_TOUCH(_AfterTouch) => {},
                        Message::POLY_TOUCH(_PolyTouch) => {},
                        Message::PROGRAM_CHANGE(_ProgramChange) => {},
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };

        outtempo
    }

    fn generate_harmony(self: @Midi, steps: i32, tonic: PitchClass, modes: Modes) -> Midi {
        let mut ev = self.clone().events;
        let mut eventlist = ArrayTrait::<Message>::new();
        let currentmode = mode_steps(modes);

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            let outnote = keynum_to_pc(*NoteOn.note)
                                .modal_transposition(
                                    tonic,
                                    currentmode,
                                    steps.try_into().unwrap(),
                                    if steps < 0 {
                                        Direction::Up(())
                                    } else {
                                        Direction::Down(())
                                    },
                                );

                            let newnote = NoteOn {
                                channel: *NoteOn.channel,
                                note: outnote,
                                velocity: *NoteOn.velocity,
                                time: *NoteOn.time
                            };

                            let notemessage = Message::NOTE_ON((newnote));
                            eventlist.append(notemessage);
                            //include original note
                            eventlist.append(*currentevent);
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            let outnote = if steps < 0 {
                                *NoteOff.note - steps.try_into().unwrap()
                            } else {
                                *NoteOff.note + steps.try_into().unwrap()
                            };

                            let newnote = NoteOff {
                                channel: *NoteOff.channel,
                                note: outnote,
                                velocity: *NoteOff.velocity,
                                time: *NoteOff.time
                            };

                            let notemessage = Message::NOTE_OFF((newnote));
                            eventlist.append(notemessage);
                            //include original note
                            eventlist.append(*currentevent);
                        },
                        Message::SET_TEMPO(_SetTempo) => { eventlist.append(*currentevent); },
                        Message::TIME_SIGNATURE(_TimeSignature) => {
                            eventlist.append(*currentevent);
                        },
                        Message::CONTROL_CHANGE(_ControlChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::PITCH_WHEEL(_PitchWheel) => { eventlist.append(*currentevent); },
                        Message::AFTER_TOUCH(_AfterTouch) => { eventlist.append(*currentevent); },
                        Message::POLY_TOUCH(_PolyTouch) => { eventlist.append(*currentevent); },
                        Message::PROGRAM_CHANGE(_ProgramChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {
                            eventlist.append(*currentevent);
                        },
                    }
                },
                Option::None(_) => { break; }
            };
        };

        Midi { events: eventlist.span() }
    }

    fn arpeggiate_chords(self: @Midi, pattern: ArpPattern) -> Midi {
        panic(array!['not supported yet'])
    }

    fn edit_dynamics(self: @Midi, curve: VelocityCurve) -> Midi {
        let mut ev = self.clone().events;
        let mut vcurve = curve.clone();
        let mut outvelocity = 0;
        let mut eventlist = ArrayTrait::<Message>::new();

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            match vcurve.getlevelattime(*NoteOn.time) {
                                Option::Some(val) => { outvelocity = val; },
                                Option::None => { outvelocity = *NoteOn.velocity; }
                            }

                            let newnote = NoteOn {
                                channel: *NoteOn.channel,
                                note: *NoteOn.note,
                                velocity: outvelocity,
                                time: *NoteOn.time
                            };
                            let notemessage = Message::NOTE_ON((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            match vcurve.getlevelattime(*NoteOff.time) {
                                Option::Some(val) => { outvelocity = val; },
                                Option::None => { outvelocity = *NoteOff.velocity; }
                            }
                            let newnote = NoteOff {
                                channel: *NoteOff.channel,
                                note: *NoteOff.note,
                                velocity: outvelocity,
                                time: *NoteOff.time
                            };
                            let notemessage = Message::NOTE_OFF((newnote));
                            eventlist.append(notemessage);
                        },
                        Message::SET_TEMPO(_SetTempo) => { eventlist.append(*currentevent); },
                        Message::TIME_SIGNATURE(_TimeSignature) => {
                            eventlist.append(*currentevent);
                        },
                        Message::CONTROL_CHANGE(_ControlChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::PITCH_WHEEL(_PitchWheel) => { eventlist.append(*currentevent); },
                        Message::AFTER_TOUCH(_AfterTouch) => { eventlist.append(*currentevent); },
                        Message::POLY_TOUCH(_PolyTouch) => { eventlist.append(*currentevent); },
                        Message::PROGRAM_CHANGE(_ProgramChange) => {
                            eventlist.append(*currentevent);
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {
                            eventlist.append(*currentevent);
                        },
                    }
                },
                Option::None(_) => { break; }
            };
        };

        Midi { events: eventlist.span() }
    }

    fn octave_double(self: @Midi, octave_count: i32) -> Midi {
        let mut ev = self.clone().events;
        let mut eventlist = ArrayTrait::<Message>::new();

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    // Always keep the original event
                    eventlist.append(*currentevent);
                    
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            // Convert note to PitchClass
                            let original_pc = keynum_to_pc(*NoteOn.note);
                            // Create new PitchClass with adjusted octave
                            let new_pc = PitchClass { 
                                note: original_pc.note, 
                                octave: if octave_count < 0 {
                                    original_pc.octave - octave_count.try_into().unwrap()
                                } else {
                                    original_pc.octave + octave_count.try_into().unwrap()
                                }
                            };
                            
                            // Convert back to keynum
                            let new_note = pc_to_keynum(new_pc);
                            
                            // Only add if the new note is within valid MIDI range (0-127)
                            if new_note <= 127 {
                                let doubled_note = NoteOn {
                                    channel: *NoteOn.channel,
                                    note: new_note,
                                    velocity: *NoteOn.velocity,
                                    time: *NoteOn.time
                                };
                                let note_message = Message::NOTE_ON((doubled_note));
                                eventlist.append(note_message);
                            }
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            // Convert note to PitchClass
                            let original_pc = keynum_to_pc(*NoteOff.note);
                            // Create new PitchClass with adjusted octave
                            let new_pc = PitchClass { 
                                note: original_pc.note, 
                                octave: if octave_count < 0 {
                                    original_pc.octave - octave_count.try_into().unwrap()
                                } else {
                                    original_pc.octave + octave_count.try_into().unwrap()
                                }
                            };
                            
                            // Convert back to keynum
                            let new_note = pc_to_keynum(new_pc);
                            
                            // Only add if the new note is within valid MIDI range (0-127)
                            if new_note <= 127 {
                                let doubled_note = NoteOff {
                                    channel: *NoteOff.channel,
                                    note: new_note,
                                    velocity: *NoteOff.velocity,
                                    time: *NoteOff.time
                                };
                                let note_message = Message::NOTE_OFF((doubled_note));
                                eventlist.append(note_message);
                            }
                        },
                        
                        // All other message types are passed through unchanged
                        Message::SET_TEMPO(_) => {},
                        Message::TIME_SIGNATURE(_) => {},
                        Message::CONTROL_CHANGE(_) => {},
                        Message::PITCH_WHEEL(_) => {},
                        Message::AFTER_TOUCH(_) => {},
                        Message::POLY_TOUCH(_) => {},
                        Message::PROGRAM_CHANGE(_) => {},
                        Message::SYSTEM_EXCLUSIVE(_) => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };

        Midi { events: eventlist.span() }
    }
}
