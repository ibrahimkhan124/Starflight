#include "Core/FlightCore.h"

#include <array>
#include <iostream>

int main() {
    int profiles = 0;
    std::array<float,24> values{};
    while (std::cin >> values[0]) {
        char comma = ' ';
        for (std::size_t i=1;i<values.size();++i) {
            if (!(std::cin >> comma >> values[i]) || comma!=',') return 1;
        }

        const starflight::Handling h{values[0],values[1],values[2],values[3],values[4]};
        const starflight::Input input{values[5],values[6],values[7],values[8],values[9]!=0};
        const starflight::Vec3 wind{values[10],values[11],values[12]};
        starflight::State state;
        state.airspeed=h.cruise;
        state.velocity={0,0,-h.cruise};
        for (int step=0;step<240;++step) starflight::AdvanceAtmosphere(state,input,wind,starflight::Step,h);

        const std::array actual{state.position.x,state.position.y,state.position.z,
            state.velocity.x,state.velocity.y,state.velocity.z,state.pitch,state.roll,state.heading,
            state.airspeed,state.stalled ? 1.f : 0.f};
        for (std::size_t i=0;i<actual.size();++i) {
            if (std::abs(actual[i]-values[13+i])>0.008f) {
                std::cerr << "Native aerodynamic profile " << profiles << " differs at field " << i
                          << " (Swift " << values[13+i] << ", C++ " << actual[i] << ")\n";
                return 1;
            }
        }
        ++profiles;
    }
    if (profiles!=3) return 1;
    std::cout << "PASS: Three native Swift aerodynamic profiles match the C++ port.\n";
}
