@echo off
cd babichChat/babich-chat-ui
npm install
npx ng build --configuration=production
cd ..
docker-compose up -d --build