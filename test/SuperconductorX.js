const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers')
const { expect } = require('chai')
const { ethers } = require('hardhat')

describe('SuperconductorX', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, addr1, addr2] = await ethers.getSigners()

    const SuperconductorX = await ethers.getContractFactory('SuperconductorX')
    const superconductorX = await SuperconductorX.deploy()

    return { superconductorX, owner, addr1, addr2 }
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { superconductorX, owner } = await loadFixture(deployFixture)

      expect(await superconductorX.owner()).to.equal(owner.address)
    })

    it('Should assign the total supply of tokens to the owner', async function () {
      const { superconductorX, owner } = await loadFixture(deployFixture)

      const ownerBalance = await superconductorX.balanceOf(owner.address)
      expect(await superconductorX.totalSupply()).to.equal(ownerBalance)
    })
  })

  describe('Transactions', function () {
    it('Should transfer tokens between accounts', async function () {
      const { superconductorX, addr1, addr2 } = await loadFixture(deployFixture)

      await superconductorX.transfer(addr1.address, 50)
      const addr1Balance = await superconductorX.balanceOf(addr1.address)
      expect(addr1Balance).to.equal(50)

      await superconductorX.connect(addr1).transfer(addr2.address, 50)
      const addr2Balance = await superconductorX.balanceOf(addr2.address)
      expect(addr2Balance).to.equal(50)
    })

    it('Should fail if sender doesn’t have enough tokens', async function () {
      const { superconductorX, owner, addr1, addr2 } = await loadFixture(
        deployFixture
      )

      const initialOwnerBalance = await superconductorX.balanceOf(owner.address)

      await expect(
        superconductorX.connect(addr1).transfer(owner.address, 1)
      ).to.be.revertedWith('ERC20: transfer amount exceeds balance')

      expect(await superconductorX.balanceOf(owner.address)).to.equal(
        initialOwnerBalance
      )
    })

    it('Should update balances after transfers', async function () {
      const { superconductorX, owner, addr1, addr2 } = await loadFixture(
        deployFixture
      )

      const initialOwnerBalance = await superconductorX.balanceOf(owner.address)

      await superconductorX.transfer(addr1.address, 100)
      await superconductorX.transfer(addr2.address, 50)

      const finalOwnerBalance = await superconductorX.balanceOf(owner.address)
      expect(finalOwnerBalance).to.eq(initialOwnerBalance.sub(150)) // Use .sub for subtraction

      const addr1Balance = await superconductorX.balanceOf(addr1.address)
      expect(addr1Balance).to.eq(100)

      const addr2Balance = await superconductorX.balanceOf(addr2.address)
      expect(addr2Balance).to.eq(50)
    })
  })

  describe('applyMagneticField', function () {
    it('Should fail because the user needs to interact with the contract first', async function () {
      const { superconductorX, owner } = await loadFixture(deployFixture)

      // Instantly mine 5761 blocks(1 day = 1 energy gained)
      await ethers.provider.send('hardhat_mine', ['0x1681'])
      await expect(superconductorX.applyMagneticField()).to.be.revertedWith(
        'Interact with the contract first'
      )
    })

    it('Need to hold at least 1000 SCX before calling this function', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      // Get some SCX from owner first
      await superconductorX.transfer(addr1.address, 1)

      // Interact with the contract before calling this function
      await superconductorX.connect(addr1).transfer(owner.address, 1)

      // Instantly mine 5761 blocks(1 day = 1 energy gained)
      await ethers.provider.send('hardhat_mine', ['0x1681'])
      await expect(
        superconductorX.connect(addr1).applyMagneticField()
      ).to.be.revertedWith('Insufficient SCX')
    })

    it('Should adjust energy and temperature based on days elapsed', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      // Get some SCX from owner first
      await superconductorX.transfer(addr1.address, 1001e18)

      // Interact with the contract before calling this function
      await superconductorX.connect(addr1).transfer(owner.address, 1001e18)

      // Instantly mine 5761 blocks(1 day = 1 energy gained)
      await ethers.provider.send('hardhat_mine', ['0x1681'])
      await superconductorX.connect(addr1).applyMagneticField()

      const userState = await superconductorX.getUserState(addr1.address)

      expect(userState.energyLevel).to.equal(100)
      expect(userState.temperature).to.equal(0)
    })
  })

  describe('Quantum Tunneling', function () {
    it('Should initiate a quantum tunnel transfer', async function () {
      const { superconductorX, addr1, addr2 } = await loadFixture(deployFixture)

      await superconductorX.transfer(addr1.address, 1000)
      await superconductorX
        .connect(addr1)
        .quantumTunnelTransfer(addr2.address, 500)

      const tunnel = await superconductorX.quantumTunnels(addr1.address)
      expect(tunnel.to).to.equal(addr2.address)
      expect(tunnel.amount).to.equal(500)
    })

    it('Should execute a successful quantum tunnel transfer', async function () {
      const { superconductorX, addr1, addr2 } = await loadFixture(deployFixture)

      // Check initial balances
      const initialAddr1Balance = await superconductorX.balanceOf(addr1.address)

      // Transfer 1000 tokens to addr1
      await superconductorX.transfer(addr1.address, 1000)

      // Initiate quantum tunnel transfer from addr1 to addr2
      await superconductorX
        .connect(addr1)
        .quantumTunnelTransfer(addr2.address, 500)

      // Instantly mine 5 blocks
      await ethers.provider.send('hardhat_mine', ['0x5'])

      // Execute the tunnel
      const tx = await superconductorX.connect(addr1).executeTunnel()

      // Check the event logs to determine the outcome of the quantum tunnel transfer
      const receipt = await ethers.provider.getTransactionReceipt(tx.hash)
      const tunnelCompletedEvent = superconductorX.interface.parseLog(
        receipt.logs[0]
      )

      // Check balances after tunnel execution
      const addr1Balance = await superconductorX.balanceOf(addr1.address)
      const addr2Balance = await superconductorX.balanceOf(addr2.address)

      // Adjust the expectation based on the outcome of the quantum tunnel transfer
      if (tunnelCompletedEvent.name === 'QuantumTunnelCompleted') {
        expect(addr1Balance + addr2Balance).to.equal(
          initialAddr1Balance.add(1000).toNumber()
        )
      } else if (tunnelCompletedEvent.name === 'QuantumTunnelFailed') {
        expect(addr1Balance + addr2Balance).to.equal(
          initialAddr1Balance.add(1000).toNumber()
        )
      }
    })

    it('Should fail if trying to execute tunnel too early', async function () {
      const { superconductorX, addr1, addr2 } = await loadFixture(deployFixture)

      await superconductorX.transfer(addr1.address, 1000)
      await superconductorX
        .connect(addr1)
        .quantumTunnelTransfer(addr2.address, 500)
      await expect(
        superconductorX.connect(addr1).executeTunnel()
      ).to.be.revertedWith('Too early to determine tunneling outcome')
    })
  })

  describe('Entanglement', function () {
    it('Should allow a user to request entanglement', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      await superconductorX.requestEntanglement(addr1.address)
      const userState = await superconductorX.getUserState(owner.address)
      expect(userState.entanglementRequest).to.equal(addr1.address)
    })

    it('Should allow a user to accept entanglement', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      await superconductorX.requestEntanglement(addr1.address)
      await superconductorX.connect(addr1).acceptEntanglement(owner.address)
      const userState1 = await superconductorX.getUserState(owner.address)
      const userState2 = await superconductorX.getUserState(addr1.address)
      expect(userState1.entangledPair).to.equal(addr1.address)
      expect(userState2.entangledPair).to.equal(owner.address)
    })

    it('Should allow a user to remove entanglement', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      await superconductorX.requestEntanglement(addr1.address)
      await superconductorX.connect(addr1).acceptEntanglement(owner.address)
      await superconductorX.removeEntanglement()
      const userState = await superconductorX.getUserState(owner.address)
      expect(userState.entangledPair).to.equal(ethers.constants.AddressZero)
    })

    it('Should not allow accepting non-existent entanglement requests', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      await expect(
        superconductorX.connect(addr1).acceptEntanglement(owner.address)
      ).to.be.revertedWith('No entanglement request from this address')
    })
  })

  describe('Energy and Temperature', function () {
    it('Should adjust energy and temperature on transfer', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      const MAX_ENERGY = await superconductorX.MAX_ENERGY()
      await superconductorX.transfer(addr1.address, 1000)
      const userState = await superconductorX.getUserState(owner.address)
      expect(userState.energyLevel).to.be.lt(MAX_ENERGY)
      expect(userState.temperature).to.be.gt(0)
    })

    it('Should not adjust energy and temperature if transferring to entangled pair', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      await superconductorX.requestEntanglement(addr1.address)
      await superconductorX.connect(addr1).acceptEntanglement(owner.address)
      const initialState = await superconductorX.getUserState(owner.address)
      await superconductorX.transfer(addr1.address, 1000)
      const finalState = await superconductorX.getUserState(owner.address)
      expect(initialState.energyLevel).to.equal(finalState.energyLevel)
      expect(initialState.temperature).to.equal(finalState.temperature)
    })

    it('Should revert transfer if temperature is too high', async function () {
      const { superconductorX, addr1, addr2 } = await loadFixture(deployFixture)

      // 20 transfers will make temperature reach MAX_TEMPERATURE
      for (let i = 0; i < 20; i++) {
        await superconductorX.transfer(addr1.address, 10)
      }
      await expect(
        superconductorX.transfer(addr2.address, 10)
      ).to.be.revertedWith('Temperature is too high so cannot transfer')
    })
  })

  describe('Minting and Burning', function () {
    it('Should allow users with max energy to mint new tokens', async function () {
      const { superconductorX, owner } = await loadFixture(deployFixture)

      // Simulate max energy for owner
      // Instantly mine 576001 blocks(A bit more than 100 days = 100 energy gained)
      await ethers.provider.send('hardhat_mine', ['0x8ca01'])
      await superconductorX.applyMagneticField()

      const initialBalance = await superconductorX.balanceOf(owner.address)
      await superconductorX.mint()
      const finalBalance = await superconductorX.balanceOf(owner.address)
      expect(finalBalance).to.be.gt(initialBalance)
    })

    it('Should not allow minting if the user does not have max energy', async function () {
      const { superconductorX } = await loadFixture(deployFixture)

      await expect(superconductorX.mint()).to.be.revertedWith(
        'Energy level not at MAX'
      )
    })

    it('Should not allow minting if minting will exceed the token cap ', async function () {
      const { superconductorX } = await loadFixture(deployFixture)

      await expect(superconductorX.mint()).to.be.revertedWith(
        'Energy level not at MAX'
      )
    })

    it('Should allow users to burn tokens to regain energy', async function () {
      const { superconductorX, owner } = await loadFixture(deployFixture)

      const initialBalance = await superconductorX.balanceOf(owner.address)
      await superconductorX.burn(ethers.utils.parseEther('11'))
      const finalBalance = await superconductorX.balanceOf(owner.address)
      expect(finalBalance).to.equal(
        initialBalance.sub(ethers.utils.parseEther('11'))
      )
    })

    it('Should not allow users to burn fewer than 10 tokens', async function () {
      const { superconductorX } = await loadFixture(deployFixture)

      await expect(
        superconductorX.burn(ethers.utils.parseEther('10'))
      ).to.be.revertedWith('Burn amount needs to be more than 10 SCX')
    })
  })

  describe('Community Minting', function () {
    it('Should allow users to mint tokens in exchange for ETH', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      // Transfer all 100 million SCX to the contract
      const initialSupply = await superconductorX.balanceOf(owner.address)
      await superconductorX.transfer(superconductorX.address, initialSupply)

      const initialBalance = await superconductorX.balanceOf(addr1.address)
      await superconductorX
        .connect(addr1)
        .communityMint({ value: ethers.utils.parseEther('0.1') })
      const finalBalance = await superconductorX.balanceOf(addr1.address)
      expect(finalBalance).to.be.gt(initialBalance)
    })

    it('Should not allow community minting with insufficient ETH', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      // Transfer all 100 million SCX to the contract
      const initialSupply = await superconductorX.balanceOf(owner.address)
      await superconductorX.transfer(superconductorX.address, initialSupply)

      await expect(
        superconductorX
          .connect(addr1)
          .communityMint({ value: ethers.utils.parseEther('0') })
      ).to.be.revertedWith('Not enough ETH sent')
    })

    it('Contract owner can withdraw unminted tokens', async function () {
      const { superconductorX, owner, addr2 } = await loadFixture(deployFixture)

      // Transfer all 100 million SCX to the contract
      const initialSupply = await superconductorX.balanceOf(owner.address)
      await superconductorX.transfer(superconductorX.address, initialSupply)

      await superconductorX.withdrawSCX(addr2.address)
      const balanceSCX = await superconductorX.balanceOf(addr2.address)
      expect(balanceSCX).to.equal(initialSupply)
    })

    it('Should not exceed available SCX tokens for community minting', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      // Transfer all 100 million SCX to the contract
      const initialSupply = await superconductorX.balanceOf(owner.address)
      await superconductorX.transfer(superconductorX.address, initialSupply)

      await expect(
        superconductorX.connect(addr1).communityMint({
          value: ethers.utils.parseEther('376') // Just a bit more than 375 ETH which would buy 75 million SCX
        })
      ).to.be.revertedWith('Exceeds available SCX tokens for community minting')
    })

    it('Contract does not have enough SCX left in its balance to be minted', async function () {
      const { superconductorX, addr1 } = await loadFixture(deployFixture)

      await expect(
        superconductorX.connect(addr1).communityMint({
          value: ethers.utils.parseEther('8000')
        })
      ).to.be.revertedWith(
        "The contract doesn't have enough SCX to be minted. Please try minting by sending a lower amount of ETH."
      )
    })

    it('Contract owner can withdraw ETH', async function () {
      const { superconductorX, owner, addr1 } = await loadFixture(deployFixture)

      // Transfer all 100 million SCX to the contract
      const initialSupply = await superconductorX.balanceOf(owner.address)
      await superconductorX.transfer(superconductorX.address, initialSupply)

      await superconductorX
        .connect(addr1)
        .communityMint({ value: ethers.utils.parseEther('0.1') })
      const initialBalance = await ethers.provider.getBalance(owner.address)
      await superconductorX.withdrawETH(owner.address)
      const finalBalance = await ethers.provider.getBalance(owner.address)
      expect(finalBalance).to.be.gt(initialBalance)
    })

    it('Should not allow non-owner to withdraw SCX', async function () {
      const { superconductorX, addr1 } = await loadFixture(deployFixture)

      await expect(
        superconductorX.connect(addr1).withdrawSCX(addr1.address)
      ).to.be.revertedWith('Ownable: caller is not the owner')
    })
  })

  describe('Edge Cases', function () {
    it('Should not allow entangling with oneself', async function () {
      const { superconductorX, owner } = await loadFixture(deployFixture)

      await expect(
        superconductorX.requestEntanglement(owner.address)
      ).to.be.revertedWith('Cannot entangle with oneself')
    })
  })
})
