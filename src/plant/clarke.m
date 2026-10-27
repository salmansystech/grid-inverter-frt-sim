function x_ab = clarke(x_abc)
%CLARKE Amplitude-invariant Clarke transform, abc (3x1) -> alpha/beta (2x1).
x_ab = [2/3*(x_abc(1) - 0.5*x_abc(2) - 0.5*x_abc(3));
        (x_abc(2) - x_abc(3))/sqrt(3)];
end
