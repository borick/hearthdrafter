java -jar /usr/local/bin/compiler.jar --js src/js/hearthdrafter.js --js_output_file public/js/hearthdrafter.min.js
java -jar /usr/local/bin/compiler.jar --js src/js/hd.js --js_output_file public/js/hd.min.js
java -jar /usr/local/bin/yuicompressor-2.4.7.jar src/css/main.css -o public/css/main.css
java -jar /usr/local/bin/yuicompressor-2.4.7.jar src/css/results.css -o public/css/results.css
java -jar /usr/local/bin/yuicompressor-2.4.7.jar src/css/hearth.css -o public/css/hearth.css
java -jar /usr/local/bin/yuicompressor-2.4.7.jar src/css/view_run.css -o public/css/view_run.css
java -jar /usr/local/bin/yuicompressor-2.4.7.jar src/css/normalize.css -o public/css/normalize.min.css

