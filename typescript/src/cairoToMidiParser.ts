export interface CairoParsedMidiEvent {
    type: string;
    channel: number;
    noteNumber: number;
    velocity: number; //how 'hard' the note is pressure. If == 0 it's and noteOff event. But a noteOff can be != 0 too.
    deltaTime: number; //distance in between the event n and the event n - 1
    microsecondsPerBeat: number; //the tempo
    numerator: number; // with [numerador/denominator] you can generate the compass
    denominator: number;
    value: number;
    pitch: number;
    clock: number;
    absoluteTime: number; // events in cairo don't have the absolute time (they only have the deltaTime), and in @tonejs/midi yes. It's required to calculate it
    controllerType: number;
    ticksPerBeat: number; ////the same as ppq
    meta: boolean; //if the event it's for metadata
    programNumber: number; //required to change instrument type, for example 24 = Nylon String Guitar
}
/**
 * Parse a cairo event into a CairoParsedMidiEvent.
 * CairoParsedMidiEvent contains all possibles properties for a MidiEvent of the library @tonejs/midi
 * the name of the properties are the same of that library for compatibility
 */
export function parseEvent(cairoEvent: string): CairoParsedMidiEvent | null {
    const match = cairoEvent.match(/Message::([A-Z_]+)\((.+)\)/);
    if (!match) return null;

    const [, type, content] = match;
    let parsedEvent: Partial<CairoParsedMidiEvent> = { type: toCamelCase(type) };
    parsedEvent.deltaTime = parseFP32x32(content.match(/time: (FP32x32 {[^}]+})/)?.[1] || "");

    switch (type) {
        case "HEADER":
            parsedEvent.ticksPerBeat = parseInt(content.match(/ticksPerBeat: (\d+)/)?.[1] || "0");
            parsedEvent.meta = true
            break;
        case "NOTE_ON":
        case "NOTE_OFF":
            parsedEvent.channel = parseInt(content.match(/channel: (\d+)/)?.[1] || "0");
            parsedEvent.noteNumber = parseInt(content.match(/note: (\d+)/)?.[1] || "0");
            parsedEvent.velocity = parseInt(content.match(/velocity: (\d+)/)?.[1] || "0");
            // This is based on midi specification
            if (parsedEvent.velocity === 0) {
                parsedEvent.type = 'noteOff'
            }
            break;

        case "SET_TEMPO":
            const tempoMag = parseFP32x32(content.match(/tempo: (FP32x32 {[^}]+})/)?.[1] || "");
            if (tempoMag !== undefined) {
                parsedEvent.microsecondsPerBeat = tempoMag;
            }
            const timeOptionMatch = content.match(/time: Option::Some\((FP32x32 {[^}]+})\)/);
            if (timeOptionMatch) {
                parsedEvent.deltaTime = parseFP32x32(timeOptionMatch[1]);
            } else {
                parsedEvent.deltaTime = undefined;
            }
            parsedEvent.meta = true
            break;

        case "TIME_SIGNATURE":
            parsedEvent.numerator = parseInt(content.match(/numerator: (\d+)/)?.[1] || "0");
            parsedEvent.denominator = parseInt(content.match(/denominator: (\d+)/)?.[1] || "0");
            parsedEvent.clock = parseInt(content.match(/clocks_per_click: (\d+)/)?.[1] || "0");
            parsedEvent.meta = true
            break;

        case "CONTROL_CHANGE":
            parsedEvent.channel = parseInt(content.match(/channel: (\d+)/)?.[1] || "0");
            parsedEvent.controllerType = parseInt(content.match(/control: (\d+)/)?.[1] || "0");
            parsedEvent.value = parseInt(content.match(/value: (\d+)/)?.[1] || "0");
            parsedEvent.type = "controller"
            break;

        case "PITCH_WHEEL":
            parsedEvent.channel = parseInt(content.match(/channel: (\d+)/)?.[1] || "0");
            parsedEvent.pitch = parseInt(content.match(/pitch: (\d+)/)?.[1] || "0");
            break;

        case "AFTER_TOUCH":
            parsedEvent.channel = parseInt(content.match(/channel: (\d+)/)?.[1] || "0");
            parsedEvent.value = parseInt(content.match(/value: (\d+)/)?.[1] || "0");
            break;

        case "POLY_TOUCH":
            parsedEvent.channel = parseInt(content.match(/channel: (\d+)/)?.[1] || "0");
            parsedEvent.noteNumber = parseInt(content.match(/note: (\d+)/)?.[1] || "0");
            parsedEvent.value = parseInt(content.match(/value: (\d+)/)?.[1] || "0");
            break;
        case "END_OF_TRACK":
            parsedEvent.meta = true
            break;
        case "PROGRAM_CHANGE":
            parsedEvent.channel = parseInt(content.match(/channel: (\d+)/)?.[1] || "0");
            parsedEvent.programNumber = parseInt(content.match(/program: (\d+)/)?.[1] || "0");
            break;
        default:
            return null;
    }

    return parsedEvent as CairoParsedMidiEvent;
}

function toCamelCase(str: string) {
    return str
        .toLowerCase()
        .split('_')
        .map((word, index) =>
            index === 0
                ? word
                : word.charAt(0).toUpperCase() + word.slice(1)
        )
        .join('');
}

function parseFP32x32(fp: string): number  {
    const match = fp.match(/FP32x32 { mag: (\d+), sign: (\w+) }/);
    if (match) {
        return parseInt(match[1], 10);
    }
    return 0;
}