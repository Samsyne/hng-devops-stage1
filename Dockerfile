# Use an official Nginx image
FROM nginx:latest

# Copy your HTML file into Nginx's web folder
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

