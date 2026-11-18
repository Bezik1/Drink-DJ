# Drink DJ
Backend side of the Drink DJ application written in FastAPI.

## Commands
Project Setup
```bash
# Creates and activates conda environemnet for the project
conda create -n drink-dj python=3.12
conda activate fastapi-env

# Setup all dependencies
conda env create -f environment.yml

# Start server
fastapi dev src/main.py
```