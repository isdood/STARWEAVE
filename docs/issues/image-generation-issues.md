## Image Generation Issues

### Notes
1) ROCm is not working yet - I think it's related to my Arch Linux setup though, not due to the project itself
2) We can properly generate images using the Python service & through the Elixir client (mix image.gen) - need to ensure the Elixir components can communicate with the Python service, rather than explicitly through the mix command. At least I'm assuming that's the case, perhaps there's a different way to do it, ie. without having the Python service running as a separate process... I think this is how the mix command works, need clarification
3) Need to now integrate with the existing web interface
