BASEURL="http://wow.zamimg.com/images/hearthstone/cards/enus/original/"
BASEURL2="http://wow.zamimg.com/images/hearthstone/cards/enus/medium/"
BASEURL3="http://wow.zamimg.com/images/hearthstone/cards/enus/small/"
#for x in `cat card_images.txt`; do wget "$BASEURL$x.png" -P ../../../public/images/cards; done
for x in `cat card_images.txt`; do wget "$BASEURL2$x.png" -P ../../../public/images/cards_medium; done
for x in `cat card_images.txt`; do wget "$BASEURL3$x.png" -P ../../../public/images/cards_small; done

