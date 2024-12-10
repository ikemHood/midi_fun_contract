#[cfg(test)]
mod tests {
    use debug::PrintTrait;
    use core::traits::Into;
    use core::traits::TryInto;
    use orion::operators::tensor::{Tensor, U32Tensor,};
    use orion::numbers::{FP32x32};
    use core::option::OptionTrait;
    use dict::Felt252DictTrait;
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
    use koji::midi::core::{MidiTrait};
    use koji::midi::pitch::{PitchClassTrait, keynum_to_pc};
    use koji::midi::modes::{major_steps};

    #[test]
    #[available_gas(10000000)]
    fn extract_notes_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newtempo = SetTempo { tempo: 0, time: Option::Some(FP32x32 { mag: 0, sign: false }) };

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

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        let tempomessage = Message::SET_TEMPO((newtempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };

        let midiobjnotesup = midiobj.extract_notes(20);

        // Assert the correctness of the modified Midi object

        // test to ensure correct positive note transpositions

        let mut ev = midiobjnotesup.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            //find test notes and assert that notes are within range 
                            assert(*NoteOn.note <= 80, 'result > 80');
                            assert(*NoteOn.note >= 40, 'result < 40');
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            //find test notes and assert that notes are within range 
                            assert(*NoteOff.note <= 80, 'result > 80');
                            assert(*NoteOff.note >= 40, 'result < 40');
                        },
                        Message::SET_TEMPO(_SetTempo) => { assert(1 == 2, 'MIDI has Tempo MSG'); },
                        Message::TIME_SIGNATURE(_TimeSignature) => {
                            assert(1 == 2, 'MIDI has TimeSig MSG');
                        },
                        Message::CONTROL_CHANGE(_ControlChange) => {
                            assert(1 == 2, 'MIDI has CC MSG');
                        },
                        Message::PITCH_WHEEL(_PitchWheel) => {
                            assert(1 == 2, 'MIDI has PitchWheel MSG');
                        },
                        Message::AFTER_TOUCH(_AfterTouch) => {
                            assert(1 == 2, 'MIDI has AfterTouch MSG');
                        },
                        Message::POLY_TOUCH(_PolyTouch) => {
                            assert(1 == 2, 'MIDI has PolyTouch MSG');
                        },
                        Message::PROGRAM_CHANGE(_ProgramChange) => {
                            assert(1 == 2, 'MIDI has PolyTouch MSG');
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {
                            assert(1 == 2, 'MIDI has PolyTouch MSG');
                        },
                    }
                },
                Option::None(_) => { break; }
            };
        };
    }

    #[test]
    #[available_gas(100000000000)]
    fn quantize_notes_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newtempo = SetTempo { tempo: 0, time: Option::Some(FP32x32 { mag: 0, sign: false }) };

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 1, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1001, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        let tempomessage = Message::SET_TEMPO((newtempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };

        let midiobjnotesup = midiobj.quantize_notes(1000);

        // Assert the correctness of the modified Midi object

        // test to ensure correct positive time quanitzations

        let mut ev = midiobjnotesup.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            //find test notes and assert that times are unchanged

                            if *NoteOn.note == 60 {
                                assert(
                                    *NoteOn.time.mag.try_into().unwrap() == 0,
                                    '1 should quantize to 0'
                                );
                                let num = *NoteOn.time.mag.try_into().unwrap();
                                'num'.print();
                                num.print();
                            } else if *NoteOn.note == 71 {
                                let num2 = *NoteOn.time.mag.try_into().unwrap();
                                assert(num2 == 1000, '1001 should quantize to 1000');

                                'num2'.print();
                                num2.print();
                            } else if *NoteOn.note == 90 {
                                let num3 = *NoteOn.time.mag.try_into().unwrap();
                                assert(num3 == 2000, '1500 should quantize to 2000');

                                'num3'.print();
                                num3.print();
                            } else {}
                        },
                        Message::NOTE_OFF(_NoteOff) => {},
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
    }

    #[test]
    #[available_gas(100000000000)]
    fn change_tempo_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 0, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1000, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        //Set Tempo

        let tempo = SetTempo { tempo: 121, time: Option::Some(FP32x32 { mag: 1500, sign: false }) };
        let tempomessage = Message::SET_TEMPO((tempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };

        let midiobjnotes = midiobj.change_tempo(120);

        // Assert the correctness of the modified Midi object

        // test to ensure correct positive note transpositions

        let mut ev = midiobjnotes.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(_NoteOn) => {},
                        Message::NOTE_OFF(_NoteOff) => {},
                        Message::SET_TEMPO(SetTempo) => {
                            assert(*SetTempo.tempo == 120, 'Tempo should be 120');
                        },
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
    }

    #[test]
    #[available_gas(10000000)]
    fn reverse_notes_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newtempo = SetTempo { tempo: 0, time: Option::Some(FP32x32 { mag: 0, sign: false }) };

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

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        let tempomessage = Message::SET_TEMPO((newtempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };
        let midiobjnotes = midiobj.reverse_notes();
        let mut ev = midiobjnotes.clone().events;

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            //find test notes and assert that times are unchanged

                            if *NoteOn.note == 60 {
                                let ptest = *NoteOn.time.mag.try_into().unwrap();
                                'reverse note time'.print();
                                ptest.print();
                            //  assert(*NoteOn.time.mag == 0, 'result should be 0');
                            } else if *NoteOn
                                .note == 71 { //   assert(*NoteOn.time.mag == 1000, 'result should be 1000');
                            } else if *NoteOn
                                .note == 90 { //   assert(*NoteOn.time.mag == 1500, 'result should be 1500');
                            } else {}
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            if *NoteOff
                                .note == 60 { //    assert(*NoteOff.time.mag == 0, 'result should be 6000');
                            } else if *NoteOff.note == 71 { // 'ptest'.print();
                            // let ptest = *NoteOff.velocity.try_into().unwrap();
                            // ptest.print();
                            // 'ptest'.print();
                            //   assert(*NoteOff.time.mag == 4500, 'result should be 4500');
                            } else if *NoteOff
                                .note == 90 { //    assert(*NoteOff.time.mag == 15000, 'result should be 15000');
                            } else {}
                        // let notemessage = Message::NOTE_OFF((newnote));
                        // eventlist.append(notemessage);
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
    }


    #[test]
    #[available_gas(100000000000)]
    fn remamp_instruments_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 0, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1000, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        // Set Instrument

        let outpc = ProgramChange {
            channel: 0, program: 7, time: FP32x32 { mag: 6000, sign: false }
        };

        let outpc2 = ProgramChange {
            channel: 0, program: 1, time: FP32x32 { mag: 6100, sign: false }
        };

        let outpc3 = ProgramChange {
            channel: 0, program: 8, time: FP32x32 { mag: 6200, sign: false }
        };
        let outpc4 = ProgramChange {
            channel: 0, program: 126, time: FP32x32 { mag: 6300, sign: false }
        };
        let outpc5 = ProgramChange {
            channel: 0, program: 126, time: FP32x32 { mag: 6300, sign: false }
        };

        let pcmessage = Message::PROGRAM_CHANGE((outpc));
        let pcmessage2 = Message::PROGRAM_CHANGE((outpc2));
        let pcmessage3 = Message::PROGRAM_CHANGE((outpc3));
        let pcmessage4 = Message::PROGRAM_CHANGE((outpc4));
        let pcmessage5 = Message::PROGRAM_CHANGE((outpc5));

        //Set Tempo

        let tempo = SetTempo { tempo: 121, time: Option::Some(FP32x32 { mag: 1500, sign: false }) };
        let tempomessage = Message::SET_TEMPO((tempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        eventlist.append(pcmessage);
        eventlist.append(pcmessage2);
        eventlist.append(pcmessage3);
        eventlist.append(pcmessage4);
        eventlist.append(pcmessage5);

        let midiobj = Midi { events: eventlist.span() };

        let midiobjnotes = midiobj.remap_instruments(2);

        // Assert the correctness of the modified Midi object

        // test to ensure correct instrument remappings occur for ProgramChange msgs

        let mut ev = midiobjnotes.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(_NoteOn) => {},
                        Message::NOTE_OFF(_NoteOff) => {},
                        Message::SET_TEMPO(_SetTempo) => {},
                        Message::TIME_SIGNATURE(_TimeSignature) => {},
                        Message::CONTROL_CHANGE(_ControlChange) => {},
                        Message::PITCH_WHEEL(_PitchWheel) => {},
                        Message::AFTER_TOUCH(_AfterTouch) => {},
                        Message::POLY_TOUCH(_PolyTouch) => {},
                        Message::PROGRAM_CHANGE(ProgramChange) => {
                            let pc = *ProgramChange.program;

                            if *ProgramChange.time.mag == 6000 {
                                assert(pc == 0, 'instruments improperly mapped');
                            } else if *ProgramChange.time.mag == 6100 {
                                assert(pc == 2, 'instruments improperly mapped');
                            } else if *ProgramChange.time.mag == 6200 {
                                assert(pc == 9, 'instruments improperly mapped');
                            } else if *ProgramChange.time.mag == 6300 {
                                assert(pc == 127, 'instruments improperly mapped');
                            } else if *ProgramChange.time.mag == 6400 {
                                assert(pc == 0, 'instruments improperly mapped');
                            } else {}
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };
    }


    #[test]
    #[available_gas(100000000000)]
    fn invert_notes_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        // Create test notes - using middle C (60) as pivot
        let newnoteon1 = NoteOn {
            channel: 0, note: 48, velocity: 100, time: FP32x32 { mag: 0, sign: false }
        }; // C3 - should become C5 (72)

        let newnoteon2 = NoteOn {
            channel: 0, note: 67, velocity: 100, time: FP32x32 { mag: 1000, sign: false }
        }; // G4 - should become Db4 (53)

        let newnoteon3 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        }; // C4 (pivot) - should stay C4 (60)

        let newnoteoff1 = NoteOff {
            channel: 0, note: 48, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 67, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        // Create messages
        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        // Add tempo message
        let newtempo = SetTempo { tempo: 120, time: Option::Some(FP32x32 { mag: 0, sign: false }) };
        let tempomessage = Message::SET_TEMPO((newtempo));

        // Build event list
        eventlist.append(tempomessage);
        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);
        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };

        // Invert around middle C (60)
        let midiobjnotes = midiobj.invert_notes(60);

        // Test the inverted notes
        let mut ev = midiobjnotes.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            if *NoteOn.time.mag == 0 {
                                // First note (C3 -> C5)
                                assert(*NoteOn.note == 72, 'C3 should invert to C5');
                            } else if *NoteOn.time.mag == 1000 {
                                // Second note (G4 -> Db4)
                                assert(*NoteOn.note == 53, 'G4 should invert to Db4');
                            } else if *NoteOn.time.mag == 1500 {
                                // Third note (pivot note)
                                assert(*NoteOn.note == 60, 'Pivot note should not change');
                            }
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            if *NoteOff.time.mag == 2000 {
                                assert(*NoteOff.note == 72, 'C3 OFF should invert to C5');
                            } else if *NoteOff.time.mag == 1500 {
                                assert(*NoteOff.note == 53, 'G4 OFF should invert to Db4');
                            } else if *NoteOff.time.mag == 5000 {
                                assert(*NoteOff.note == 60, 'Pivot OFF should not change');
                            }
                        },
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
    }
}
