import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AsoEbiMarketPlaceModule = buildModule("AsoEbiMarketPlaceModule", (m) => {

  const escrowAddress = "0x46e806234eE4cd34dD6dFf82074c29B5cA0fD1D0";
  const save = m.contract("AsoEbiMarketPlace", [escrowAddress]);

  return { save };

});

export default AsoEbiMarketPlaceModule;