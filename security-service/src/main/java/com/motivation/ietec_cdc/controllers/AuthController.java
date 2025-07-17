package com.motivation.ietec_cdc.controllers;

import com.motivation.ietec_cdc.dto.LoginRequest;
import com.motivation.ietec_cdc.models.User;
import com.motivation.ietec_cdc.services.AuthService;
import com.motivation.ietec_cdc.services.BindingResultService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.*;

/**
 * Controller for handling authentication and registration requests.
 *
 * @author EgorBusuioc
 * @since 06.05.2025
 */
@Tag(name = "Auth", description = "Authentication API service")
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final BindingResultService bindingResultService;

    @Value("${server.ip}")
    private String serverIp;

    /**
     * Registers a new user with the provided details.
     *
     * @param user the user details for registration
     * @param bindingResult the result of the validation
     * @return a response entity with the registration status
     */
    @Operation(
            summary = "Registration endpoint for a creator only.",
            description = "There a creator can register yourself with email, password, and company name. Patient registration is not allowed.",
            requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    description = "User details for registration",
                    required = true,
                    content = @Content(
                            mediaType = "application/json",
                            schema = @Schema(implementation = User.class),
                            examples = @ExampleObject(value = "{ \"email\": \"audi@gmail.com\", \"password\": \"Password123!\", \"companyName\": \"audi\"}"))),
            responses = {
                    @ApiResponse(responseCode = "200", description = "Creator registered successfully",
                            content = @Content(
                                    schema = @Schema(implementation = String.class),
                                    examples = @ExampleObject(value = "Creator registered successfully"))),
                    @ApiResponse(responseCode = "400", description = "Validation error",
                            content = @Content(
                                    schema = @Schema(implementation = String.class),
                                    examples = @ExampleObject(value = "Email should not be empty\n" +
                                            "Password must be at least 8 characters long and contain at least one uppercase letter and one digit"))),
            }
    )
    @PostMapping("/register")
    public ResponseEntity<String> register(@Valid @RequestBody User user, BindingResult bindingResult) {

        ResponseEntity<String> errorResponse = bindingResultService.getErrorMessage(bindingResult);
        if (errorResponse.getStatusCode().isError()) {
            return errorResponse;
        }

        try {
            authService.registerNewUser(user); // Assuming null for creatorId as it's not provided in the request
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }

        return ResponseEntity.ok("Creator registered successfully");
    }

    /**
     * Logs in a user with the provided email and password.
     *
     * @param user the login request containing email and password
     * @return a response entity with the login status and JWT token
     */
    @Operation(
            summary = "Login for a creator and a patient",
            description = "Login with the provided email and password",
            requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    description = "User login details",
                    required = true,
                    content = @Content(
                            mediaType = "application/json",
                            schema = @Schema(implementation = LoginRequest.class),
                            examples = @ExampleObject(value = "{ \"email\": \"johndoe@gmail.com/randomcompany@ietec.com\", \"password\": \"Password123!\" }"))),
            responses = {
                    @ApiResponse(responseCode = "200", description = "User logged in successfully",
                            content = @Content(
                                    schema = @Schema(implementation = String.class),
                                    examples = @ExampleObject(value = "There will be a JWT token here, bla bla bla"))),
                    @ApiResponse(responseCode = "400", description = "Invalid email or password",
                            content = @Content(
                                    schema = @Schema(implementation = String.class),
                                    examples = @ExampleObject(value = "Invalid email or password"))),
            }
    )
    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody LoginRequest user) {

        try {
            return ResponseEntity.ok(authService.loginUser(user));
        }
        catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body("Invalid email or password");
        }
    }

    @GetMapping("/test-ip/with-header")
    public ResponseEntity<String> testCurrentIP(@RequestHeader("GatewayIP") String gatewayIp) {
        return ResponseEntity.ok("You're accessing the security-server with IP: " + serverIp +
                " and the Gateway IP is: " + gatewayIp);
    }

    @GetMapping("/test-ip")
    public ResponseEntity<String> testCurrentIP() {
        return ResponseEntity.ok("You're accessing the security-server with IP: " + serverIp);
    }
}
