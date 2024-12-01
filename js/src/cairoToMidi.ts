import {Header, Midi, Track} from "@tonejs/midi";
import * as fs from "fs";
import {parseEvent, CairoParsedMidiEvent} from './midi'
import {MidiData, MidiEvent, MidiHeader} from "midi-file";

export function cairoToMidi(cairoFilePath: string, outputFile: string): Midi {
    //file = Read the file cairoFilePath
    const fileContent = fs.readFileSync(cairoFilePath, "utf-8");
    const lines = fileContent.split("\n");

    const midiEvents:CairoParsedMidiEvent[] = [];

    lines.forEach((line) => {
        const event = parseEvent(line);
        if (event) {
            midiEvents.push(event);
        }
    });

    const parsedHeader = midiEvents.shift();
    const tracks = splitByEndOfTrack(midiEvents)

    tracks.forEach(track => {
        let currentTicks = 0;
        track.forEach((event, idx) => {
            currentTicks += event.deltaTime;
            event.absoluteTime = currentTicks;
        });
    })

    const midiData: MidiData = {
        header: parsedHeader as unknown as MidiHeader,
        tracks: tracks as unknown as Array<MidiEvent[]>
    }


    const midi = new Midi();
    midi.header = new Header(midiData)

    tracks.forEach(track => {
        const midiTrack = new Track(track as unknown as MidiEvent[], midi.header)
        midi.tracks.push(midiTrack)
    })


    const midiBuffer = midi.toArray();
    fs.writeFileSync(outputFile, new Uint8Array(midiBuffer));
    return midi
}




export async function loadMidi(generatedMidi: Midi) {
    // load a midi file in the browser
    const fileBuffer = fs.readFileSync("/Users/jrmncos/forks/midi_fun_contract/example/HeyBulldog.mid");

    const midi = new Midi(fileBuffer);

    //the file name decoded from the first track
    const name = midi.name
    //get the tracks
    // midi.tracks.forEach(track => {
    //     //tracks have notes and controlChanges
    //
    //     //notes are an array
    //     const notes = track.notes
    //     notes.forEach(note => {
    //         //note.midi, note.time, note.duration, note.name
    //     })
    //
    //     //the control changes are an object
    //     //the keys are the CC number
    //     track.controlChanges[64]
    //     //they are also aliased to the CC number's common name (if it has one)
    //     track.controlChanges.sustain.forEach(cc => {
    //         // cc.ticks, cc.value, cc.time
    //     })
    //
    //     //the track also has a channel and instrument
    //     //track.instrument.name
    // })
}




// --- Script Execution ---
if (require.main === module) {
    const [,, cairoFilePath, outputFile] = process.argv;

    if (!cairoFilePath || !outputFile) {
        console.error("Usage: ts-node script.ts <cairoFilePath> <outputFile>");
        process.exit(1);
    }

    try {
        const midi = cairoToMidi(cairoFilePath, outputFile);
        // @ts-ignore
        loadMidi(midi).then(() => console.log(`MIDI file successfully created at ${outputFile}`))
    } catch (error) {
        // @ts-ignore
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}

function splitByEndOfTrack(events: CairoParsedMidiEvent[]): CairoParsedMidiEvent[][] {
    const result: CairoParsedMidiEvent[][] = [];
    let currentChunk: CairoParsedMidiEvent[] = [];

    for (const event of events) {
        currentChunk.push(event); // Agregar el evento al fragmento actual

        if (event.type === "endOfTrack") {
            result.push(currentChunk); // Finalizar el fragmento actual
            currentChunk = []; // Crear un nuevo fragmento
        }
    }

    return result;
}





