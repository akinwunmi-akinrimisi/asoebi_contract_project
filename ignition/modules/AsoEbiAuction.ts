import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AsoEbiAutionModule = buildModule("AsoEbiAutionModule", (m) => {


  // Define constructor arguments for the Escrow contract
  const escrowAddress = "0x46e806234eE4cd34dD6dFf82074c29B5cA0fD1D0"; //Add Escrow Address

  const save = m.contract("AsoEbiAution", [escrowAddress]);

  return { save };

});

export default AsoEbiAutionModule;