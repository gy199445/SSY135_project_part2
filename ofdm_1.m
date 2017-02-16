%% define constants
% channel
Fs = 1E6;   %ADC sample freq.
Ts = 1/Fs;
%N0 = 2*2.07E-20; %Noise PSD(in W/Hz)
fd = 100;   %doppler/Hz
EbN0_dB = linspace(0,25,50);    %simulation Eb/No range
EbN0 = 10.^(EbN0_dB/10);
%L = 10^(-101/10);    %path loss
tau = [0 4]';
fdTs = fd*Ts;
P = [0.5 0.5]'; %power delay profile
% ofdm tx setup
%Pt = 0.1;   %tx power
mod_type = 16;   %modulation type (4,16,64 - QAM)
%fc = 2E9;   %carrier frequency
Ncp = 5;    %twice the delay spread
%Bc = 0;
%Tc = 0;
N = 64;
Nsym = 100;%number of ofdm symbols in one packet
%Tsym = 0.01;    %symbol interval?
% check setup
if ((N+Ncp)*fdTs > 0.01 ||(N+Ncp)*Nsym>9000 )
    warning('time-varing frequency response assumption invalid')
end
%simulation round
max_err_num = 500; %stop simulation when 500 bit errors
max_symbol_num = 200*10000;%or stop when reach this number of symbols
k = 1;
%% ofdm BER simulation
%transmitting energy
%E = Pt * (N+Ncp) * Ts;
Es = 1; %fix the Es, change N0
%bit error counter
err = zeros(length(EbN0),1);
%BER simulation symbol by symbol
for j = 1:length(EbN0)
    %calculate noise power
    EsN0 = EbN0(j) * log2(mod_type);%energy per tx bit
    sigma = sqrt(1/(EsN0*2*1));
    ofdm_symbol_mat = zeros(N+Ncp,Nsym);%the matrix contains Nsym ofdm symbols
    while (err(j) <= max_err_num || k<=max_symbol_num)
        %information bit matrix
        b = randi([0 1],N*log2(mod_type),Nsym);
        for i = 1:Nsym
            %ofdm generator
            ofdm_symbol_mat(:,i) = ofdm_sym_gen(b(:,i),N,Ncp,mod_type,Es,Ts);
        end
        %path loss
        %ofdm_symbol = ofdm_symbol * L;
        %fading
        ofdm_symbol = reshape(ofdm_symbol_mat,[],1);%vector contains Nsym ofdm symbols
        [y, h] = Fading_Channel(ofdm_symbol,tau,fdTs,P);
        %add noise
        y = y + (randn(length(y),1)*sigma + 1j * randn(length(y),1)*sigma);%the noise's amplitude is too small
        %remove transient
        y = y(1:end-max(tau));
        y = reshape(y,N+Ncp,Nsym);
        %demodulate each symbol
        for i = 1:Nsym
            %remove cp,fft
            y_temp = y(:,i);
            r = sqrt(1/N)*fft(y_temp(Ncp+1:end));
            %correct phase and gain
            c = fft([h(1 + (i-1)*(Ncp+N),1) 0 0 0 h(1 + (i-1)*(Ncp+N),2)],N);
            C = diag(c);
            A = diag(1./(c.*conj(c)));
            if isnan(A)
                warning('channel gain is 0')
            end
            %demodulate
            r_ = A*C'*r;
            %scatter(real(r_),imag(r_))
            s_hat = qamdemod(r_,mod_type,'UnitAveragePower',true);
            b_hat = de2bi(s_hat,log2(mod_type));
            b_hat = reshape(b_hat,[],1);
            %counting error
            err(j) = err(j) + sum(b_hat ~= b(:,i));
        end
        k = k + Nsym;
    end
    err_rate = err/(Nsym * N * log2(mod_type));
end