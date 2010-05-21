% Plot a sum of sine waves, using the frequencies from Strayer & Johnston's
% (2001) simulated-driving pursuit task and with random phase offsets.
% 
% A sine wave is basically sin(2 * pi * (omega * x + phi)), where omega is
% the frequency in Hz, phi is the phase offset, and x is the times, in
% seconds, at which the sine wave is sampled.  This code computes several
% sine waves with different frequencies and random phase offsets, then
% averages them.

rate = 100; % sampling rate in Hz
dur = 100; % duration in seconds
omega = [.07, .15, .23]; % frequency in Hz
phi = rand(1, numel(omega)); % offset in cycles; range = [0, 1)

% compute time samples
x = (0:rate*dur) ./ rate;

% compute average sine wave
y = mean(sin(2 .* pi .* (repmat(omega', 1, numel(x)) .* ...
                         repmat(x, numel(omega), 1) + ...
                         repmat(phi', 1, numel(x)))));

plot(x, y);
