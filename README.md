<div align="center">
  <!-- <img src="https://raw.githubusercontent.com/teakzc/crunchwrap/refs/heads/main/logo.svg" alt="Logo" width="256" height="256"/> -->

  <h1 align="center"><b>crunchwrap</b></h1>
  <p align="center"></p>
  
  Powerful ffrostfall/crunchyroll wrapper with many features

[![License](https://img.shields.io/github/license/teakzc/crunchwrap?style=for-the-badge)](https://github.com/teakzc/crunchwrap/blob/main/LICENSE)
[![Documentation](https://img.shields.io/badge/Documentation-Website-blue?style=for-the-badge)](https://teakzc.github.io/crunchwrap/)

</div>

# crunchwrap

## 📦 Installation

[npm](https://npmjs.com/):

```zsh
npm install @rbxts/crunchwrap
```

[pesde](https://pesde.dev/):

```zsh
pesde add teakzc/crunchwrap
```

[wally](https://wally.run/):

```toml
[dependencies]
crunchwrap = "teakzc/crunchwrap@VERSION"
```

## ⭐ Features

- Strictly typed API
- Force animation to have a fixed playback length
- Speed control and animation pausing and also looping
- Reverse time in animations
- Smooth fade in/out system with easing curves
- Provide your own easing curves to be used
- Motor6D support
- Selective rig solving

# Documentation

Documentation will only contain key information as for now.
It will be hosted on a website soon, stay tuned. All functions are documented.

## Fade

### IMPORTANT!

When using fades make sure you have a IDLE track in the background. Why?

Because fades utilize weights, and they only work if you have another track playing.

When configuring `fade` times do not set either fadein or fadeout to zero, as this does nothing.

`fade` time is not measured in `seconds` but in a value ranging from 0 to 1; from the start of the animation to the end. This allows for easy fade configuration without calculation.

For `fadeout` values, they are calculated to perfectly fadeout until the animation ends by looking at the remaining alpha of the track and the alpha of the fadeout time. It will wait until fadeout alpha is bigger than track alpha to begin fading out.

Do not worry about fade in and fade out overlapping as it is supported and will be smooth!

For crunchwrap, you can provide a custom easing curve via `fadecurve` as seen below. If none are specified they will default to this.

https://www.desmos.com/calculator/zlussqyagp

```luau
crunchwrap.add_animation(keyframe, rig, {
    alpha = 1,
    weight = 1,
    priority = 1,
    fadein = 0.25, -- Ends at 0.25 alpha
    fadeout = 0.5, -- Starts at 0.5 alpha
    fadecurve = {
        fadeout = function(alpha: number) -- Custom easing curve for fade out
            return alpha ^ 3
        end
    }
})
```

## Removing Animations

The function `remove_animation` will stop the animation with a smooth fade out time. If you want to stop it instantly consider using `force_remove_animation` instead.
