### Readme for Dockerfile and Bash Script

#### Dockerfile Overview

This Dockerfile is designed to create Docker images for a pathology application with different computational backends including CPU, PyTorch, and TensorFlow. It utilizes a multi-stage build process to efficiently manage dependencies and reduce the final image size.
The CPU-oriented Docker image is tailored for preprocessing tasks that do not necessitate deep learning capabilities. This renders it significantly lightweight while maintaining a consistent environment with its GPU counterparts, ensuring seamless integration and functionality across different computational scenarios.

**Stages:**
1. **Builder Stage**: Compiles ASAP and PyVips from source.
2. **Base-CPU Stage**: Sets up a base image and copies compiled ASAP and PyVips together with necessary libraries and Python environment.
3. **PyTorch Stage**: Builds on Base-CPU, adds PyTorch with CUDA support and install GPU/deep learing specific packages.
4. **TensorFlow Stage**: Also builds on Base-CPU, adds TensorFlow  and install GPU/deep learing specific packages.
5. **CPU Stage**: Builds on base-cpu and install specific preprocessing packages.

#### Bash Script for Building and Pushing Images

The accompanying bash script automates the process of building and pushing these Docker images to a registry. It allows you to either build all images at once or select a specific stage to build. The script prompts for a version tag for each build.

**Key Features:**
- Interactive prompts for selecting build stages and specifying version tags.
- Handles tagging and pushing both version-specific and latest tags to a registry.
- Utilizes the multi-stage capabilities of the Dockerfile for efficient building.

**Usage:**
Run the script in the terminal, follow the prompts to select the build stage(s) and specify version tags. The script will handle the rest, building and pushing images to the specified registry.

**Requirements:**
- Docker installed and configured on your system.
- Access to the specified Docker registry with necessary permissions.

This setup provides a flexible and efficient way to manage Docker images for different computational backends in a pathology application environment.
