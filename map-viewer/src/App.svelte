<script>
    import { onMount } from "svelte";
    import Information from "./components/Information.svelte";
    import Map from "./components/Map.svelte";
    export let Neutralino;
    export let Username = "";
    export let versionInfo = {
        NL_VERSION,
        NL_PORT,
        NL_OS,
        NL_NAME,
    };
    let basepath = "C:\\Games\\Call of Duty\\uo";
    var key = NL_OS == "Windows" ? "USERNAME" : "USER";
    Neutralino.os.getEnvar(key, function (data) {
        Username = data.value;
    });

    // Neutralino.debug.log(
    //     "INFO",
    //     "This is a log message",
    //     function (data) {
    //         console.log(data);
    //     },
    //     function () {
    //         console.error("error");
    //     }
    // );
    let files = [];
    Neutralino.filesystem.readDirectory(
        "C:\\Games\\Call of Duty\\uo",
        function (data) {
            files = data.files.filter(
                (file) =>
                    file.type === "file" &&
                    file.name.match(/.pk3/) &&
                    !file.name.match(/pakuo|.tmp/)
            );
            console.log(files);
        },
        function () {
            console.error("error");
        }
    );

    //const StreamZip = require("node-stream-zip");
    // const zip = new StreamZip({
    //     file: "archive.zip",
    //     storeEntries: true,
    // });

    let filePath = "";

    function openFile() {
        Neutralino.os.dialogOpen(
            "Open a file..",
            function (data) {
                console.log(data);
                filePath = data.file.split("\\");
                filePath.pop();
                basepath = filePath.join("\\");
                console.log(basepath);
            },
            function () {
                console.error("error");
            }
        );
    }

    function getMapName(stdout, layout = false) {
        const matches = stdout.match(/.+(?=.dds|.jpg)/g);

        if (layout) {
            const hudfile = matches
                ? matches.find((match) => match.match(/hud@layout_/))
                : undefined;
            if (hudfile) {
                return hudfile.split("\\").pop();
            } else {
                return undefined;
            }
        }

        const mapname = matches.join("").match(/levelshots\\.*/);
        if (!mapname) console.log("none found", { stdout, matches });
        return mapname
            ? mapname
                  .pop()
                  .split("\\")
                  .pop()
                  .replace(/hud@layout_/, "")
            : "";
    }
    let minScale = 1;
    let quality = 0.75;
    let width = 500;
    let height = 500;

    function redraw(ctx, img) {
        let offsetX = 0;
        let offsetY = 0;
        let scale = (minScale = Math.max(
            width / img.width,
            height / img.height
        ));
        if (offsetX < 0) offsetX = 0;
        if (offsetY < 0) offsetY = 0;
        let limit = img.width * scale - width;
        if (offsetX > limit) offsetX = limit;
        limit = img.height * scale - height;
        if (offsetY > limit) offsetY = limit;
        ctx.resetTransform();
        ctx.clearRect(0, 0, width, height);
        ctx.translate(-offsetX, -offsetY);
        ctx.scale(scale, scale);
        ctx.drawImage(img, 0, 0);
    }

    async function reduceImageSize(url, canvas) {
        if (!canvas) {
            canvas = document.createElement("canvas");
            canvas.setAttribute("height", height);
            canvas.setAttribute("width", width);
        }
        let ctx = canvas.getContext("2d");
        let img = new Image();
        img.src = url;

        return new Promise((resolve) => {
            setTimeout(() => {
                redraw(ctx, img);
                resolve(canvas.toDataURL("image/jpeg", quality));
            }, 500);
        });
    }

    onMount(() => {});

    function addLayout(filename, layoutname, index) {
        const layoutcanvas = document.createElement("canvas");
        layoutcanvas.setAttribute("height", height);
        layoutcanvas.setAttribute("width", width);
        Neutralino.os.runCommand(
            `convert.bat ${filename} layouts/${layoutname} "${basepath}"`,
            async (data) => {
                if (data.stdout && data.stdout != "\n") {
                    files[index].layout = await reduceImageSize(
                        "data:image/jpg;base64," + data.stdout,
                        layoutcanvas
                    );
                    console.log("found hud@layout", layoutname);
                }
            }
        );
    }

    export async function readFile(filename, index) {
        return new Promise((resolve) => {
            Neutralino.os.runCommand(
                `7z l "${basepath}\\${filename}.pk3" levelshots/`,
                (data) => {
                    const canvas = document.createElement("canvas");
                    canvas.setAttribute("height", height);
                    canvas.setAttribute("width", width);
                    const mapname =
                        data.stdout && data.stdout.match(/.+(?=.dds|.jpg)/)
                            ? getMapName(data.stdout)
                            : filename;
                    files[index].mapname = mapname;
                    const layout = getMapName(data.stdout, true);
                    if (data.stdout.includes(".jpg")) {
                        Neutralino.os.runCommand(
                            `7z x "${basepath}\\${filename}.pk3" levelshots/${mapname}.jpg -so | openssl base64 2>&1`,
                            async (data) => {
                                if (data.stdout && data.stdout != "\n") {
                                    files[index].image = await reduceImageSize(
                                        "data:image/jpg;base64," + data.stdout,
                                        canvas
                                    );
                                    console.log("found jpg", mapname);
                                    if (layout)
                                        addLayout(filename, layout, index);
                                    resolve(files[index].image);
                                }
                            }
                        );
                    } else if (data.stdout.includes(".dds")) {
                        Neutralino.os.runCommand(
                            `convert.bat ${filename} ${mapname} "${basepath}"`,
                            async (data) => {
                                if (data.stdout && data.stdout != "\n") {
                                    files[index].image = await reduceImageSize(
                                        "data:image/jpg;base64," + data.stdout,
                                        canvas
                                    );
                                    console.log("found dds", mapname);
                                    if (layout)
                                        addLayout(filename, layout, index);
                                    resolve(files[index].image);
                                }
                            }
                        );
                    } else {
                        console.log("Did not find an levelshot for", filename);
                        files[index].image =
                            "data:image/png;base64," +
                            `iVBORw0KGgoAAAANSUhEUgAAAAUA
AAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO
9TXL0Y4OHwAAAABJRU5ErkJggg==`; // RED DOT
                        if (layout) addLayout(filename, layout, index);
                        resolve(files[index].image);
                    }
                }
            );
        });
    }

    async function readFiles() {
        for (let index = 0; index < files.length; index++) {
            if (!files[index].image)
                await readFile(files[index].name.replace(/\.\w*/, ""), index);
        }
        console.log("Finished reading files");
    }

    function saveAll() {
        Neutralino.storage.putData(
            {
                bucket: "files",
                content: {
                    files: files,
                    basepath: basepath,
                },
            },

            // executes on successful storage of data
            function () {
                console.log("Data saved to storage/files.json");
            },
            // executes if an error occurs

            function () {
                console.log("An error occured while saving the Data");
            }
        );
    }
    function loadData() {
        Neutralino.storage.getData(
            "files",
            // executes when data is successfully retrieved.
            function (content) {
                console.log("Restored saved data \n");

                // the data that has been retrieved.
                files = content.files.filter(
                    (file) => !file.name.match(/pakuo|.tmp/)
                );
                if (conent.basepath) basepath = content.basepath;
            },
            // executes if an error occurs
            function () {
                console.log("An error occured while retrieving the data.");
            }
        );
    }
    loadData();
    let searchTerm = "";
</script>

<style>
    #neutralinoapp {
        text-align: center;
    }
    #neutralinoapp h1 {
        font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
        font-size: 20px;
        color: #000000;
    }
    .container {
        display: flex;
        justify-content: center;
        position: relative;
        flex-direction: row;
        flex-wrap: wrap;
    }
</style>

<div id="neutralinoapp">
    <h1>Hi {Username} <small>{basepath}</small></h1>
    Filter:
    <input bind:value={searchTerm} />
    <button on:click={() => openFile()}>Select Basepath 📄</button>
    <button on:click={() => readFiles()}>Read All 📄</button>
    <button on:click={() => saveAll()}>Save All 📄</button>
    <button on:click={() => loadData()}>Load All 📄</button>
    <div class="container">
        {#each files.filter((item) => item.name.indexOf(searchTerm) !== -1) as file}
            <Map
                {file}
                on:click={() => readFile(file.name.replace(/\.\w*/, ''), files.indexOf(file))} />
        {/each}
    </div>

    <Information {versionInfo} />
</div>
