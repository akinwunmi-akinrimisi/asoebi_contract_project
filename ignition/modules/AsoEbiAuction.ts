import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AsoEbiAutionModule = buildModule("AsoEbiAutionModule", (m) => {
  
  
    // Define constructor arguments for the Escrow contract
  const escrowAddress  = ""; //Add Escrow Address

  const save = m.contract("AsoEbiAution", [escrowAddress]);

  return { save };
  
});

export default AsoEbiAutionModule;