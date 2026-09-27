# BeamScale Desktop Infra

Single-host infrastructure for running BeamScale on a developer-owned laptop or desktop.

This repository is intentionally separate from `beamscale/bmscl-infra`, which remains the production infrastructure authority.

The desktop appliance target is one trusted host with one long-lived BEAM VM, an optional Cloudflare Tunnel, and `beamscale-desktop-daemon` as the machine lifecycle authority.

Implementation is developed through pull requests from this bootstrap commit.
