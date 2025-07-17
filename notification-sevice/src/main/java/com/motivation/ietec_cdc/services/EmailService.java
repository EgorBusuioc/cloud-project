package com.motivation.ietec_cdc.services;

import com.motivation.ietec_cdc.dto.interfaces.MailRequestBase;
import com.motivation.ietec_cdc.dto.MailRequestCreate;
import com.motivation.ietec_cdc.dto.MailRequestReset;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.core.io.ClassPathResource;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;

import java.io.FileNotFoundException;
import org.springframework.beans.factory.annotation.Value;

/**
 * @author EgorBusuioc
 * 02.06.2025
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender emailSender;
    private final TemplateEngine templateEngine;

    public void sendLink(MailRequestBase mailRequest) throws Exception {
        MimeMessage message = emailSender.createMimeMessage();
        MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

        helper.setFrom("ietecproject@gmail.com");
        helper.setTo(mailRequest.getEmail());
        helper.setSubject("Reset your password");
        Context context = new Context();
        if (mailRequest instanceof MailRequestCreate) {
            context.setVariable("message", "Hello, Dear user,<br>" +
                    "We have received a request to create a new account for you." +
                    "You have to change your generated password, using the button below.<br>" +
                    "Please, change your password as soon as possible, because this link will expire in <b>6</b> hours.");
        } else if (mailRequest instanceof MailRequestReset) {
            context.setVariable("message", "Hello, Dear user, <br> " +
                    "We have received a request to reset your password. " +
                    "Please, change your password as soon as possible, because this link will expire in <b>6</b> hours.");
        }

        // Nutze die Frontend-URL aus der Konfiguration
        context.setVariable("resetLink", "localhost:8080" + "/reset-password?token=" + mailRequest.getToken());
        String htmlContent = templateEngine.process("reset_password", context);
        helper.setText(htmlContent, true);

         ClassPathResource image = new ClassPathResource("IETEC_OnlinePortal_Negativ.png");
         if (!image.exists()) {
             log.error("Logo image not found in classpath. Please ensure the image is located in the resources directory.");
         }
         helper.addInline("logoImage", image, "image/png");

        emailSender.send(message);
        log.info("Reset password email sent to: {}", mailRequest.getEmail());
    }
}
