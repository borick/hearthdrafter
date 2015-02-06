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
      });
    
});