# Use official minimal Node.js image
FROM node:20-alpine

# Set working directory inside container
WORKDIR /app

# Copy package metadata and install dependencies
COPY src/package*.json ./
# COPY src/package*.json ./
RUN npm ci --omit=dev

# Copy application source code
COPY src/ .

# Expose application port
EXPOSE 8080

# Command to launch the app
CMD ["node", "app.js"]
