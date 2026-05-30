# 1. Use an official lightweight Python runtime as a parent image
FROM python:3.10-slim

# 2. Set the working directory inside the container structure
WORKDIR /app

# 3. Copy application dependency records first to optimize Docker cache layers
COPY requirements.txt .

# 4. Install production system dependencies and application libraries
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy the remaining local microservice application source code
COPY . .

# 6. Expose the internal network port that the application listens on
EXPOSE 5000

# 7. Define the final runtime command execution blueprint
CMD ["python", "app.py"]