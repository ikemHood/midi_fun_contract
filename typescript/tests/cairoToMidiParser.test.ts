import {parseEvent} from "../src/cairoToMidiParser";

describe('parseEvent', () => {
    test('should return null for invalid events', () => {
        expect(parseEvent("InvalidEventString")).toBeNull();
        expect(parseEvent("Message::UNKNOWN_TYPE()")).toBeNull();
    });

    test('should correctly parse a HEADER event', () => {
        const cairoEvent = 'Message::HEADER(Header { ticksPerBeat: 480 }),';
        const result = parseEvent(cairoEvent);
        expect(result).toEqual({
            type: 'header',
            ticksPerBeat: 480,
            meta: true,
            deltaTime: 0
        });
    });

    test('should correctly parse a NOTE_ON event', () => {
        const cairoEvent = 'Message::NOTE_ON(NoteOn { channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 184, sign: false } })';
        const result = parseEvent(cairoEvent);
        expect(result).toEqual({
            type: 'noteOn',
            channel: 0,
            noteNumber: 60,
            velocity: 100,
            deltaTime: 184
        });
    });

    test('should change the type to "noteOff" when velocity is 0 in NOTE_ON', () => {
        const cairoEvent = 'Message::NOTE_ON(NoteOn { channel: 0, note: 60, velocity: 0, time: FP32x32 { mag: 189, sign: false } })';
        const result = parseEvent(cairoEvent);
        expect(result).toEqual({
            type: 'noteOff',
            channel: 0,
            noteNumber: 60,
            velocity: 0,
            deltaTime: 189
        });
    });

    test('should correctly parse a SET_TEMPO event', () => {
        const cairoEvent = 'Message::SET_TEMPO(SetTempo { tempo: FP32x32 { mag: 600000, sign: false }, time: Option::Some(FP32x32 { mag: 0, sign: false }) })';
        const result = parseEvent(cairoEvent);
        expect(result).toEqual({
            type: 'setTempo',
            microsecondsPerBeat: 600000,
            deltaTime: 0,
            meta: true
        });
    });

    test('should handle END_OF_TRACK events', () => {
        const cairoEvent = 'Message::END_OF_TRACK(EndOfTrack { time: FP32x32 { mag: 1, sign: false } }),';
        const result = parseEvent(cairoEvent);
        expect(result).toEqual({
            type: 'endOfTrack',
            deltaTime: 1,
            meta: true
        });
    });
});
