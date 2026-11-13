# identity-lab
A single-VM lab for running a self-managed Tyk Gateway with Docker Compose. It uses a single HTTPS origin, isolates backend services on an internal Docker network, and separates browser authentication from API routing to keep access tokens out of the SPA. The lab uses the open-source Tyk Gateway without the Tyk Dashboard
