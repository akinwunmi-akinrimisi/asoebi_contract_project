import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const EscrowModule = buildModule("EscrowModule", (m) => {
  
  
    // Define constructor arguments for the Escrow contract
  const feePercentage  = 10; //change to prefered fee percentage
  const feeRecipientAddress = ""; //add address to receive feee percentage 

  const save = m.contract("Escrow", [feePercentage,feeRecipientAddress]);

  return { save };
});

export default EscrowModule;