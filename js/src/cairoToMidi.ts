import {Midi, Track} from "@tonejs/midi";
import * as fs from "fs";
import {parseEvent, CairoParsedMidiEvent} from './midi'
import {MidiEvent} from "midi-file";

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



    const midi = new Midi();

    let currentTicks = 0;
    midiEvents.forEach((midiEvent, idx) => {
        currentTicks += midiEvent.deltaTime;
        midiEvent.absoluteTime = currentTicks;
    });

    const track = new Track(midiEvents as unknown as MidiEvent[], midi.header)

    midi.tracks.push(track)


    // midiEvents.forEach(midiEvent => {
    //
    //
    //     switch (midiEvent.type) {
    //         case "note_on":
    //             // const bpm = 120;
    //             // const deltaTimeTicks = midiEvent.time;
    //             // const tickDurationInSeconds = 60 / (bpm * ppq);
    //             // const timeInSeconds = deltaTimeTicks * tickDurationInSeconds;
    //
    //             const nextNote = midiEvents[idx + 1]
    //             if (nextNote != null && nextNote.type == "note_on" && nextNote.note == midiEvent.note) {
    //
    //                 const noteOnEvent = midiEvent
    //                 const noteOffEvent = nextNote
    //
    //                 const durationTicks = noteOffEvent.time;
    //                 track.addNote({
    //                     midi: midiEvent.note,
    //                     ticks: noteOnEvent.time,
    //                     velocity: noteOnEvent.velocity / 127,
    //                     durationTicks: noteOffEvent.time,
    //                 });
    //             }
    //             break;
    //
    //         case "note_off":
    //             track.addNote({
    //                 midi: midiEvent.note,
    //                 velocity: 0,
    //                 time: midiEvent.time,
    //             });
    //             break;
    //
    //         case "set_tempo":
    //             header.setTempo(60000000/midiEvent.tempo)
    //             break;
    //
    //         case "time_signature":
    //             // Mapeo del evento Cairo
    //             const ticks = midiEvent.time ? midiEvent.time * ppq : 0; // Convertir tiempo a ticks
    //             const timeSignature = [midiEvent.numerator, midiEvent.denominator];
    //
    //             // Agregar el evento al encabezado
    //             header.timeSignatures.push({
    //                 ticks: ticks,
    //                 timeSignature: timeSignature,
    //             });
    //             break;
    //
    //         case "control_change":
    //             track.addCC({
    //                 number: midiEvent.control,
    //                 value: midiEvent.value,
    //                 time: 0
    //             });
    //             break;
    //
    //         default:
    //             console.warn(`Unsupported event type: ${midiEvent.type}`);
    //             break;
    //     }
    // })

    const midiBuffer = midi.toArray();
    fs.writeFileSync(outputFile, new Uint8Array(midiBuffer));
    return midi
}




export async function loadMidi(generatedMidi: Midi) {
    // load a midi file in the browser
    const fileBuffer = fs.readFileSync("/Users/jrmncos/forks/midi_fun_contract/example/YungTruong.mid");

    const midi = new Midi(fileBuffer);

    //the file name decoded from the first track
    const name = midi.name
    //get the tracks
    midi.tracks.forEach(track => {
        //tracks have notes and controlChanges

        //notes are an array
        const notes = track.notes
        notes.forEach(note => {
            //note.midi, note.time, note.duration, note.name
        })

        //the control changes are an object
        //the keys are the CC number
        track.controlChanges[64]
        //they are also aliased to the CC number's common name (if it has one)
        track.controlChanges.sustain.forEach(cc => {
            // cc.ticks, cc.value, cc.time
        })

        //the track also has a channel and instrument
        //track.instrument.name
    })
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

    // Devolver el resultado
    return result;
}





