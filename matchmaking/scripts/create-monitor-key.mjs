import {mkdir,writeFile,access} from "node:fs/promises";import {randomBytes} from "node:crypto";
await mkdir(".secrets",{recursive:true,mode:0o700});const path=".secrets/monitor-key.txt";
try{await access(path);console.log("Using the existing local monitor key.");}catch{await writeFile(path,randomBytes(32).toString("hex"),{mode:0o600,flag:"wx"});console.log("Created .secrets/monitor-key.txt. The key was not printed.");}
