// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract SuperconductorX is ERC20, ReentrancyGuard, Ownable {
    // Maximum token cap
    uint256 public constant MAX_TOKEN_CAP = 1000000000e18; // 1 billion tokens

    // Max temperature and energy constants
    uint256 public constant MAX_TEMPERATURE = 100;
    uint256 public constant MAX_ENERGY = 100;
    uint256 public constant UNIVERSAL_CONSTANT_TEMPERATURE = 5;
    uint256 public constant UNIVERSAL_CONSTANT_ENERGY = 2;

    // Estimated number of blocks in a day
    uint256 public constant NUM_BLOCKS_DAY = 5760;

    // User state
    struct UserState {
        uint256 energyLevel;
        uint256 temperature;
        address entanglementRequest;
        address entangledPair;
        uint256 lastActionBlock;
    }
    mapping(address => UserState) public userStates;

    // Events for creating entanglement
    event EntanglementRequested(
        address indexed requester,
        address indexed pair
    );
    event EntanglementAccepted(
        address indexed requester,
        address indexed accepter
    );
    event EntanglementRemoved(address indexed user);

    // Quantum Tunnel
    struct Tunnel {
        address to;
        uint256 amount;
    }
    mapping(address => Tunnel) public quantumTunnels;
    mapping(address => uint256) public tunnelTargetBlock;

    // Events for quantum tunnel transfer
    event QuantumTunnelInitiated(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 targetBlock
    );
    event QuantumTunnelCompleted(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event QuantumTunnelFailed(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    // Tier system for community minting of SCX
    struct Tier {
        uint256 tokenCap;
        uint256 tokensSold;
        uint256 priceInETH;
    }
    Tier[] public tiers;
    uint256 public currentTier;
    mapping(uint256 => mapping(address => uint256)) public tierParticipants;
    mapping(uint256 => address[]) public tierParticipantAddresses;

    // Events for community minting of SCX
    event CommunityMint(
        address indexed user,
        uint256 amountMinted,
        uint256 ethAmount
    );
    event SCXWithdrawn(address indexed to, uint256 amount);

    // Other events
    event MagneticFieldApplied(address indexed user, uint256 daysElapsedReward);
    event EnergyAdjusted(address indexed user, uint256 newEnergyLevel);
    event TemperatureAdjusted(address indexed user, uint256 newTemperature);
    event Minted(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 ethAmount);

    constructor() ERC20("SuperconductorX", "SCX") {
        _mint(msg.sender, 100000000 * 10 ** decimals()); // 100 million initial supply
        tiers.push(Tier(25000000e18, 0, 5e12)); // Tier 1: 25 million at 0.000005 ETH
    }

    // Applying an external force, similar to applying a magnetic field on a superconductor.
    // A user's energy and temperature levels are adjusted based on the days elapsed since their last interaction.
    function applyMagneticField() public {
        require(balanceOf(msg.sender) > 1000e18, "Insufficient SCX");
        require(
            userStates[msg.sender].lastActionBlock != 0,
            "Interact with the contract first"
        );

        uint256 daysElapsed = (block.number -
            userStates[msg.sender].lastActionBlock) / NUM_BLOCKS_DAY;
        if (daysElapsed > 0) {
            uint256 baseReward = daysElapsed;
            uint256 tokenMultiplier = Math.sqrt(balanceOf(msg.sender) / 1e18);
            uint256 totalDaysReward = baseReward * tokenMultiplier;

            userStates[msg.sender].energyLevel += totalDaysReward;
            userStates[msg.sender].temperature = userStates[msg.sender]
                .temperature < totalDaysReward
                ? 0
                : userStates[msg.sender].temperature - totalDaysReward;
            _autoAdjust();
            userStates[msg.sender].lastActionBlock = block.number;

            emit MagneticFieldApplied(msg.sender, totalDaysReward);
            emit EnergyAdjusted(msg.sender, userStates[msg.sender].energyLevel);
            emit TemperatureAdjusted(
                msg.sender,
                userStates[msg.sender].temperature
            );
        }
    }

    // Requesting entanglement mimics quantum entanglement in superconductors.
    // By becoming entangled, the users' energy decreases and temperature increases.
    function requestEntanglement(address pair) public {
        require(pair != msg.sender, "Cannot entangle self");
        userStates[msg.sender].entanglementRequest = pair;
        userStates[msg.sender].energyLevel = userStates[msg.sender]
            .energyLevel < UNIVERSAL_CONSTANT_ENERGY
            ? 0
            : userStates[msg.sender].energyLevel - UNIVERSAL_CONSTANT_ENERGY;
        userStates[msg.sender].temperature += UNIVERSAL_CONSTANT_TEMPERATURE;
        _autoAdjust();

        emit EntanglementRequested(msg.sender, pair);
        emit EnergyAdjusted(msg.sender, userStates[msg.sender].energyLevel);
        emit TemperatureAdjusted(
            msg.sender,
            userStates[msg.sender].temperature
        );
    }

    // Accepting an entanglement increases temperature and decreases energy, mimicking quantum behavior.
    function acceptEntanglement(address requester) public {
        require(
            userStates[requester].entanglementRequest == msg.sender,
            "No request"
        );
        userStates[requester].entangledPair = msg.sender;
        userStates[msg.sender].entangledPair = requester;
        userStates[requester].entanglementRequest = address(0);
        userStates[msg.sender].energyLevel = userStates[msg.sender]
            .energyLevel < UNIVERSAL_CONSTANT_ENERGY
            ? 0
            : userStates[msg.sender].energyLevel - UNIVERSAL_CONSTANT_ENERGY;
        userStates[msg.sender].temperature += UNIVERSAL_CONSTANT_TEMPERATURE;
        _autoAdjust();

        emit EntanglementAccepted(requester, msg.sender);
        emit EnergyAdjusted(msg.sender, userStates[msg.sender].energyLevel);
        emit TemperatureAdjusted(
            msg.sender,
            userStates[msg.sender].temperature
        );
    }

    // Users can remove their entanglement status.
    function removeEntanglement() public {
        userStates[msg.sender].entanglementRequest = address(0);
        userStates[msg.sender].entangledPair = address(0);
        userStates[msg.sender].energyLevel = userStates[msg.sender]
            .energyLevel < UNIVERSAL_CONSTANT_ENERGY
            ? 0
            : userStates[msg.sender].energyLevel - UNIVERSAL_CONSTANT_ENERGY;
        userStates[msg.sender].temperature += UNIVERSAL_CONSTANT_TEMPERATURE;
        _autoAdjust();

        emit EntanglementRemoved(msg.sender);
        emit EnergyAdjusted(msg.sender, userStates[msg.sender].energyLevel);
        emit TemperatureAdjusted(
            msg.sender,
            userStates[msg.sender].temperature
        );
    }

    // Modified ERC20 transfer that adjusts user states and ensures certain conditions.
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        if (userStates[msg.sender].entangledPair != recipient) {
            require(
                userStates[msg.sender].temperature < MAX_TEMPERATURE,
                "Temperature is too high so cannot transfer"
            );
            userStates[msg.sender].energyLevel = userStates[msg.sender]
                .energyLevel < UNIVERSAL_CONSTANT_ENERGY
                ? 0
                : userStates[msg.sender].energyLevel -
                    UNIVERSAL_CONSTANT_ENERGY;
            userStates[msg.sender]
                .temperature += UNIVERSAL_CONSTANT_TEMPERATURE;
            _autoAdjust();
            userStates[msg.sender].lastActionBlock = block.number;
            emit EnergyAdjusted(msg.sender, userStates[msg.sender].energyLevel);
            emit TemperatureAdjusted(
                msg.sender,
                userStates[msg.sender].temperature
            );
        }

        return super.transfer(recipient, amount);
    }

    // Represents quantum tunneling. Tokens are locked and then either successfully transferred or returned based on a probabilistic outcome.
    function initiateQuantumTunnel(
        address to,
        uint256 amount
    ) external nonReentrant {
        // User should have the tokens they're trying to send
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        // Lock the tokens
        _transfer(msg.sender, address(this), amount);

        // Set up the tunneling data
        quantumTunnels[msg.sender] = Tunnel({to: to, amount: amount});

        // 5 is arbitrary, represents the delay in blocks before tunnel effect happens
        // We chose 5 because a new epoch ensures a new set of validators so less chance to game the system
        tunnelTargetBlock[msg.sender] = block.number + 5;

        emit QuantumTunnelInitiated(
            msg.sender,
            to,
            amount,
            tunnelTargetBlock[msg.sender]
        );
    }

    // Represents the execution of a quantum tunneling event in the contract.
    // A tunnel is initiated by a user, and this function determines whether the tunneling is successful or not.
    // If users are entangled, the probability of success increases, mirroring the probabilistic nature of quantum mechanics.
    function completeQuantumTunnel() external nonReentrant {
        require(
            tunnelTargetBlock[msg.sender] > 0,
            "No tunnel initiated by this user"
        );
        require(
            block.number >= tunnelTargetBlock[msg.sender],
            "Too early to determine tunneling outcome"
        );

        Tunnel memory tunnel = quantumTunnels[msg.sender];

        bool tunnelSuccessful;
        uint256 randomNumber = block.prevrandao; // block.difficulty

        // If the users are entangled, use two least significant bits
        if (userStates[msg.sender].entangledPair == tunnel.to) {
            // Check the least significant bit and second least significant bit of the previous blockhash
            // This will have 75% chance of success
            tunnelSuccessful =
                (randomNumber & 1 == 1) ||
                (randomNumber & 2 == 2);
        } else {
            // Check the least significant bit of the previous blockhash
            // This will have 50% chance of success
            tunnelSuccessful = randomNumber & 1 == 1;
        }

        if (tunnelSuccessful) {
            _transfer(address(this), tunnel.to, tunnel.amount);
            userStates[msg.sender].energyLevel +=
                (tunnel.amount * 100000000 * 10 ** decimals()) /
                totalSupply();
            emit QuantumTunnelCompleted(msg.sender, tunnel.to, tunnel.amount);

            uint256 mintAmount = 5 * 10 ** decimals();
            require(
                totalSupply() + mintAmount <= MAX_TOKEN_CAP,
                "Minting will exceed the token cap"
            );

            userStates[msg.sender].lastActionBlock = block.number;

            uint256 userAmount = mintAmount - 1 * 10 ** decimals();
            uint256 contractAmount = mintAmount - userAmount;

            _mint(msg.sender, userAmount); // 80% of the amount to the user
            _mint(address(this), contractAmount); // 20% remains in the contract

            emit Minted(msg.sender, userAmount);
            emit Minted(address(this), contractAmount);
        } else {
            _transfer(address(this), msg.sender, tunnel.amount);
            emit QuantumTunnelFailed(msg.sender, tunnel.to, tunnel.amount);
        }

        // Clean up
        delete quantumTunnels[msg.sender];
        delete tunnelTargetBlock[msg.sender];
    }

    // Will return true if the tunnel transfer is in a pending state for the provided user and false otherwise.
    function isTunnelPending(address user) public view returns (bool) {
        return
            tunnelTargetBlock[user] > 0 &&
            block.number < tunnelTargetBlock[user];
    }

    // Users with max energy can mint new tokens. This function adjusts their energy and temperature after minting.
    function mint() public nonReentrant {
        require(
            userStates[msg.sender].energyLevel == MAX_ENERGY,
            "Energy level not at MAX"
        );

        uint256 mintAmount = 15 * 10 ** decimals();
        require(
            totalSupply() + mintAmount <= MAX_TOKEN_CAP,
            "Minting will exceed the token cap"
        );

        userStates[msg.sender].energyLevel = 0;
        userStates[msg.sender].temperature = MAX_TEMPERATURE;
        userStates[msg.sender].lastActionBlock = block.number;

        uint256 userAmount = mintAmount - 5 * 10 ** decimals();
        uint256 contractAmount = mintAmount - userAmount;

        _mint(msg.sender, userAmount); // 2/3rd of the amount to the user
        _mint(address(this), contractAmount); // 1/3rd remains in the contract

        emit Minted(msg.sender, userAmount);
        emit Minted(address(this), contractAmount);
    }

    // Users can burn tokens to regain energy.
    function burn(uint256 amount) public nonReentrant {
        require(
            amount > 10 * 10 ** decimals(),
            "Burn amount needs to be more than 10 SCX"
        );
        userStates[msg.sender].energyLevel +=
            (amount * 100000000 * 10 ** decimals()) /
            totalSupply();
        userStates[msg.sender].temperature = 0;
        _autoAdjust();

        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    // Users can mint tokens in exchange for ETH.
    function communityMint() external payable nonReentrant {
        require(currentTier < tiers.length, "All tiers are exhausted");

        Tier storage tier = tiers[currentTier];

        uint256 maxTokensAvailable = Math.min(
            balanceOf(address(this)),
            tier.tokenCap - tier.tokensSold
        );

        uint256 amountToMint = (msg.value / tier.priceInETH) * 10 ** decimals();
        if (amountToMint > maxTokensAvailable) {
            amountToMint = maxTokensAvailable;
        }

        require(
            amountToMint > 0,
            "Not enough ETH sent or no tokens available for minting"
        );

        uint256 ethRequired = (amountToMint * tier.priceInETH) /
            10 ** decimals();
        uint256 ethToRefund = msg.value - ethRequired;

        tier.tokensSold += amountToMint;
        _transfer(address(this), msg.sender, amountToMint);

        // Record the participant's purchase
        if (tierParticipants[currentTier][msg.sender] == 0) {
            tierParticipantAddresses[currentTier].push(msg.sender);
        }
        tierParticipants[currentTier][msg.sender] += amountToMint;

        if (ethToRefund > 0) {
            payable(msg.sender).transfer(ethToRefund);
        }

        // Move to the next tier if the current tier is exhausted
        if (tier.tokensSold == tier.tokenCap) {
            currentTier++;
        }

        emit CommunityMint(msg.sender, amountToMint, ethRequired);
    }

    // Get the number of participants in a specific tier
    function getTierParticipantCount(
        uint256 tierIndex
    ) external view returns (uint256) {
        return tierParticipantAddresses[tierIndex].length;
    }

    // Get the participant address and their purchase amount for a specific tier and index
    function getTierParticipant(
        uint256 tierIndex,
        uint256 participantIndex
    ) external view returns (address, uint256) {
        address participant = tierParticipantAddresses[tierIndex][
            participantIndex
        ];
        uint256 amount = tierParticipants[tierIndex][participant];
        return (participant, amount);
    }

    // Contract owner can withdraw all the SCX tokens.
    function withdrawSCX(address to) external onlyOwner {
        uint256 amount = balanceOf(address(this));
        _transfer(address(this), to, amount);

        emit SCXWithdrawn(to, amount);
    }

    // Contract owner can withdraw ETH from the contract.
    function withdrawETH(address payable to) external onlyOwner {
        uint256 ethAmount = address(this).balance;
        to.transfer(ethAmount);

        emit ETHWithdrawn(to, ethAmount);
    }

    // Utility function to fetch user state.
    function getUserState(address user) public view returns (UserState memory) {
        UserState memory userState = userStates[user];
        return userState;
    }

    // Internal function to ensure user's energy and temperature are within limits.
    function _autoAdjust() internal {
        if (userStates[msg.sender].temperature > MAX_TEMPERATURE) {
            userStates[msg.sender].temperature = MAX_TEMPERATURE;
        }

        if (userStates[msg.sender].energyLevel > MAX_ENERGY) {
            userStates[msg.sender].energyLevel = MAX_ENERGY;
        }

        emit EnergyAdjusted(msg.sender, userStates[msg.sender].energyLevel);
        emit TemperatureAdjusted(
            msg.sender,
            userStates[msg.sender].temperature
        );
    }

    receive() external payable {}

    fallback() external payable {}
}
