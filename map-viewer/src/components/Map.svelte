<script>
    import { createEventDispatcher } from "svelte";
    import { readFile } from "../App.svelte";
    const dispatch = createEventDispatcher();
    export let file;
</script>

<style>
    img {
        max-height: 150px;
    }
    img:hover {
        max-height: 300px;
    }
    .map {
        position: relative;
        flex: 1;
    }
    button {
        position: absolute;
        bottom: 0;
    }
</style>

<div class="map">
    <h5>{file.name.replace(/\.\w*/, '')}</h5>
    <button on:click={(event) => dispatch('click', event)}>Update 📄</button>
    {#if file.layout}<img src={file.layout} />{/if}
    <img src={file.image} />
</div>
