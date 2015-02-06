var selected = [];

$(document).ready(function() {
    var options = {
        valueNames: [ 'name' ],
        item: '<li><h3 class="name"></h3></li>'
    };
    var userList = new List('cards', options, cards);
    userList.sort('name');
    $(".name").button()
      .click(function( event ) {
        event.preventDefault();  
        var element = $(this);
        selected.push(element);
        userList.clear();
      });
    $(".name").css({ width: '210px' });
    $(".card").css({ position: absolute });
});

function preload(arrayOfImages) {
    $(arrayOfImages).each(function(){
        $('<img/>')[0].src = this;
    });
}
var images = ['http://wow.zamimg.com/images/hearthstone/cardbacks/original/Card_Back_Default.png'];
preload(images);