function x_abc = inv_clarke(x_ab)
%INV_CLARKE Inverse amplitude-invariant Clarke transform, alpha/beta -> abc.
x_abc = [x_ab(1);
         -0.5*x_ab(1) + sqrt(3)/2*x_ab(2);
         -0.5*x_ab(1) - sqrt(3)/2*x_ab(2)];
end
