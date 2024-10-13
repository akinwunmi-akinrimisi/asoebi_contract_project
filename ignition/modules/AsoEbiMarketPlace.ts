import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AsoEbiMarketPlaceModule = buildModule("AsoEbiMarketPlaceModule", (m) => {

  const save = m.contract("AsoEbiMarketPlace");

  return { save };
  
});

export default AsoEbiMarketPlaceModule;