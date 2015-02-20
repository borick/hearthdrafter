BASEURL="http://wow.zamimg.com/images/hearthstone/cards/enus/original/"
for x in `cat card_images.txt`; do wget "$BASEURL$x.png" -P ../../../public/images/cards; done
