@ u@
identifier var;
position p;
@@

var++

@script:python@
var << u.var;
p << u.p;
@@


print "* file: %s signed reference to unsigned %s on line %s" % (p[0].file,var,p[0].line)

