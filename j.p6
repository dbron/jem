#!/usr/bin/env perl6

grammar J {

   rule TOP {^ <line>* $};
   rule line {^^ .* $$};

}

my Str $jsl = '(+/ % #) 1 2 3 4';
my Str $jml = $jsl,"\n",$jsl;

say J.parse($jsl);
say J.parse($jml);
