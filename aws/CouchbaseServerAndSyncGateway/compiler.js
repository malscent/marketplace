#!/usr/local/bin/node

const fs = require("fs"),
      readline = require("readline");
let template = JSON.parse(fs.readFileSync("./couchbase-amzn-lnx2.template", "utf-8"));
const replacementRegex = /\$__\w*__/g

async function processEmbeddedLines(file) {
    let lines = [];
    const reader = readline.createInterface({
        input: fs.createReadStream(file),
        crlfDelay: Infinity
    });

    for await (const line of reader) {
        if (line.match(replacementRegex)) {
            lines.push(...performReplacement(line));
        } else {
            lines.push(line + "\n");
        }
        
    }
    var userData= {
        "Fn::Base64": {
            "Fn::Join": ["", lines] 
        }
    }
    return userData
}

function performReplacement(line) {
    const values = [];
    index = 0;
    while ((match = replacementRegex.exec(line)) != null) {
        values.push(line.substring(index, match.index));
        index = match.index + match[0].length;
        value = match[0].substring(3, match[0].length - 2)
        if (value.startsWith("AWS")) {
            value = "AWS::" + value.substring(3);
        }
        values.push({ "Ref": value });
    }
    if (index == line.length) {
        values.push("\n");
    } else {
        values.push(line.substring(index) + "\n");
    }
    return values;
}


let args = process.argv.slice(2);
if (!args[0] || args[0] === "" || !fs.existsSync(args[0])) {
    console.error("You must specify the mapping file to use.");
    process.exit(1);
}
const mapping = JSON.parse(fs.readFileSync(args[0], "utf-8"));
template.Mappings = mapping;

processEmbeddedLines('./embedded_server.sh').then(t => {
    template.Resources.ServerLaunchConfiguration.Properties.UserData = t;
    return processEmbeddedLines('./embedded_gateway.sh');
}).then(x => {
    template.Resources.SyncGatewayLaunchConfiguration.Properties.UserData = x;
    console.log(JSON.stringify(template, null, 4));
});

