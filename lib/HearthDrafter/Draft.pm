package HearthDrafter::Draft;

use Mojo::Base 'Mojolicious::Controller';

sub select_class {
    my $self = shift;
    
    print STDERR "CLASS: " . $self->stash('class');
    
    $self->render('draft/select_class');
}

sub selection {
    my $self = shift;
    
    my $classData = $self->model->class->classData();
    my $class = $self->stash('class');
    
    if (!exists($classData->{$class})) {
        die "$class is not a valid class";
    }
    
    $self->render('draft/selection');
}

1;