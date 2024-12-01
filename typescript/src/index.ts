import {cairoToMidi} from "./cairoToMidiEvent";


if (require.main === module) {
    const [,, cairoFilePath, outputFile] = process.argv;

    if (!cairoFilePath || !outputFile) {
        console.error("Usage: ts-node index.ts <cairoFilePath> <outputFile>");
        process.exit(1);
    }

    try {
        cairoToMidi(cairoFilePath, outputFile);
    } catch (error) {
        // @ts-ignore
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}







