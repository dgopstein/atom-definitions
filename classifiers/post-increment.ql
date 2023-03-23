import cpp

from PostfixCrementOperation e
where not(e instanceof ExprInVoidContext)
select e as Operator, e.getOperand() as Operand, e.getLocation() as Location