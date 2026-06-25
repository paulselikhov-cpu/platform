@echo off
cd babichChat/babich-ui
npm install
npx ng build --configuration=production
cd ..
docker-compose up -d --build