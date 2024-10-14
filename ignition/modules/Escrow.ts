import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const EscrowModule = buildModule("EscrowModule", (m) => {


  // Define constructor arguments for the Escrow contract
  const feePercentage = 25; //change to prefered fee percentage
  const feeRecipientAddress = "0x2C3C7d196B273FC2c38601dF3d17Fb0dc1968328"; //add address to receive feee percentage 

  const save = m.contract("Escrow", [feePercentage, feeRecipientAddress]);

  return { save };
});

export default EscrowModule;