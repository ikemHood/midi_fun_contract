export interface CairoParsedMidiEvent {
    type: string;
    channel: number;
    noteNumber: number;
    velocity: number;
    deltaTime: number;
    tempo: number;
    numerator: number;
    denominator: number;
    value: number;
    pitch: number;
    clock: number;
    absoluteTime: number;
    controllerType: number;
}

function toCamelCase(str: string) {
    return str
        .toLowerCase() // Convertir a minúsculas
        .split('_')    // Dividir por el guion bajo
        .map((word, index) =>
            index === 0
                ? word
                : word.charAt(0).toUpperCase() + word.slice(1) // Capitalizar la primera letra desde el segundo elemento
        )
        .join(''); // Unir las palabras sin espacios
}

export function parseEvent(line: string): CairoParsedMidiEvent | null {
    const match = line.match(/Message::([A-Z_]+)\((.+)\)/);
    if (!match) return null;

    const [, type, content] = match;
    let parsedEvent: Partial<CairoParsedMidiEvent> = { type: toCamelCase(type) };
    parsedEvent.deltaTime = parseFP32x32(content.match(/time: (FP32x32 {[^}]+})/)?.[1] || "");

    switch (type) {
        case "NOTE_ON":
        case "NOTE_OFF":
            parsedEvent.channel = parseInt(content.match(/channel: (\d+)/)?.[1] || "0");
            parsedEvent.noteNumber = parseInt(content.match(/note: (\d+)/)?.[1] || "0");
            parsedEvent.velocity = parseInt(content.match(/velocity: (\d+)/)?.[1] || "0");
            if (parsedEvent.velocity === 0) {
                parsedEvent.type = 'noteOff'
            }
            break;

        case "SET_TEMPO":
            const tempoMag = parseFP32x32(content.match(/tempo: (FP32x32 {[^}]+})/)?.[1] || "");
            if (tempoMag !== undefined) {
                parsedEvent.tempo = tempoMag;
            }
            const timeOptionMatch = content.match(/time: Option::Some\((FP32x32 {[^}]+})\)/);
            if (timeOptionMatch) {
                parsedEvent.deltaTime = parseFP32x32(timeOptionMatch[1]);
            } else {
                parsedEvent.deltaTime = undefined;  // No `time` provided
            }
            break;

        case "TIME_SIGNATURE":
            parsedEvent.numerator = parseInt(content.match(/numerator: (\d+)/)?.[1] || "0");
            parsedEvent.denominator = parseInt(content.match(/denominator: (\d+)/)?.[1] || "0");
            parsedEvent.clock = parseInt(content.match(/clocks_per_click: (\d+)/)?.[1] || "0");
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
            break;

        default:
            return null;
    }

    return parsedEvent as CairoParsedMidiEvent;
}

function parseFP32x32(fp: string): number  {
    const match = fp.match(/FP32x32 { mag: (\d+), sign: (\w+) }/);
    if (match) {
        return parseInt(match[1], 10);  // Solo el valor 'mag' como número
    }
    return 0;
}