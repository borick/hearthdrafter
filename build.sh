echo Building...
java -jar /usr/local/bin/compiler.jar --js src/js/*.js --js_output_file public/js/hearthdrafter.min.js
cd src/css
rm *.min.css 2>/dev/null
java -jar /usr/local/bin/yuicompressor-2.4.7.jar -o '.css$:.min.css' *.css
cd ../..
rm public/css/*.min.css 2>/dev/null
mv src/css/*.min.css public/css/
echo Done.
