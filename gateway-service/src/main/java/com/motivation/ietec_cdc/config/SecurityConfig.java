package com.motivation.ietec_cdc.config;

import com.motivation.ietec_cdc.exceptions.CustomExceptionHandlers;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.oauth2.server.resource.authentication.ReactiveJwtAuthenticationConverterAdapter;
import org.springframework.security.web.server.SecurityWebFilterChain;

/**
 * This class is responsible for configuring the security settings of the application.
 * @author EgorBusuioc
 * 08.05.2025
 */
@Configuration
@EnableWebFluxSecurity
public class SecurityConfig {

    @Bean
    public SecurityWebFilterChain springSecurityFilterChain(ServerHttpSecurity http) {
        return http
                .csrf(ServerHttpSecurity.CsrfSpec::disable)
                .authorizeExchange(exchanges -> exchanges
                        .pathMatchers(HttpMethod.POST, "/auth/login", "/auth/register", "/auth/reset-request", "/auth/reset-password").permitAll()
                        .pathMatchers(HttpMethod.POST, "/auth/create-request").hasRole("CREATOR")
                        .pathMatchers(HttpMethod.GET, "/auth/test-ip").permitAll()
                        .pathMatchers(HttpMethod.GET, "/auth/test-ip/**").authenticated()

                        .pathMatchers(HttpMethod.POST, "/post-questionnaires/**", "/diagnostic-sheets/**", "/pre-questionnaires/**").hasAnyRole("USER", "CREATOR")
                        .pathMatchers("/post-questionnaires/**", "/diagnostic-sheets/**", "/pre-questionnaires/**", "/diagram-detail-changes/**").hasRole("CREATOR")
                        .pathMatchers(HttpMethod.GET, "/api/**", "/management/users-by-maker").hasRole("CREATOR")

                        .pathMatchers("/v3/api-docs/**", "/swagger-ui/**", "/security-swagger/**", "/data-swagger/**").permitAll()
                        .pathMatchers("/user/**").hasRole("USER")
                        .pathMatchers("/creator/**").hasRole("CREATOR")

                        .pathMatchers("/actuator/**", "/check/**").permitAll()
                        .anyExchange().authenticated()
                )
                .exceptionHandling(ex -> ex
                        .accessDeniedHandler(new CustomExceptionHandlers().accessDeniedHandler())
                        .authenticationEntryPoint(new CustomExceptionHandlers().authenticationEntryPoint())
                )
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(grantedAuthoritiesExtractor()))
                )
                .build();
    }

    private ReactiveJwtAuthenticationConverterAdapter grantedAuthoritiesExtractor() {
        JwtGrantedAuthoritiesConverter converter = new JwtGrantedAuthoritiesConverter();
        converter.setAuthoritiesClaimName("role");
        converter.setAuthorityPrefix("");

        JwtAuthenticationConverter authConverter = new JwtAuthenticationConverter();
        authConverter.setJwtGrantedAuthoritiesConverter(converter);
        return new ReactiveJwtAuthenticationConverterAdapter(authConverter);
    }
}
